module Libuv
    class UDP < Handle
        include Net


        SEND_DATA_ERROR = "data must be a String".freeze
        TTL_ARGUMENT_ERROR = "ttl must be an Integer".freeze
        MULTICAST_ARGUMENT_ERROR = "multicast_address must be a String".freeze
        INTERFACE_ARGUMENT_ERROR = "interface_address must be a String".freeze
        HANDLE_CLOSED_ERROR = "unable to send as handle closed".freeze


        def initialize(loop)
            @loop = loop

            udp_ptr = ::Libuv::Ext.create_handle(:uv_udp)
            error = check_result(::Libuv::Ext.udp_init(loop.handle, udp_ptr))

            super(udp_ptr, error)
        end

        def bind(ip, port)
            return if @closed
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)

            sockaddr = create_sockaddr(ip, port)
            error = check_result ::Libuv::Ext.udp_bind(handle, sockaddr, 0)
            reject(error) if error
        end

        def open(fd, binding = true, callback = nil, &blk)
            return if @closed
            error = check_result UV.udp_open(handle, fd)
            reject(error) if error
        end

        def sockname
            return [] if @closed
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.udp_getsockname(handle, sockaddr, len)
            get_ip_and_port(UV::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def join(multicast_address, interface_address)
            return if @closed
            assert_type(String, multicast_address, MULTICAST_ARGUMENT_ERROR)
            assert_type(String, interface_address, INTERFACE_ARGUMENT_ERROR)

            error = check_result ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_join_group)
            reject(error) if error
        end

        def leave(multicast_address, interface_address)
            return if @closed
            assert_type(String, multicast_address, MULTICAST_ARGUMENT_ERROR)
            assert_type(String, interface_address, INTERFACE_ARGUMENT_ERROR)

            error = check_result ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_leave_group)
            reject(error) if error
        end

        # Starts reading from the handle
        # Renamed to match Stream
        def start_read
            return if @closed
            error = check_result ::Libuv::Ext.udp_recv_start(handle, callback(:on_allocate), callback(:on_recv))
            reject(error) if error
        end

        # Stops reading from the handle
        # Renamed to match Stream
        def stop_read
            return if @closed
            error = check_result ::Libuv::Ext.udp_recv_stop(handle)
            reject(error) if error
        end

        def send(ip, port, data)
            # NOTE:: Similar to stream.rb -> write
            deferred = @loop.defer
            if !@closed
                begin
                    assert_type(String, ip, IP_ARGUMENT_ERROR)
                    assert_type(Integer, port, PORT_ARGUMENT_ERROR)
                    assert_type(String, data, SEND_DATA_ERROR)

                    sockaddr = create_sockaddr(ip, port)

                    # local as this variable will be avaliable until the handle is closed
                    @sent_callbacks ||= []

                    #
                    # create the curried callback
                    #
                    callback = FFI::Function.new(:void, [:pointer, :int]) do |req, status|
                        ::Libuv::Ext.free(req)
                        # remove the callback from the array
                        # assumes sends are done in order
                        promise = @sent_callbacks.shift[0]
                        resolve promise, status
                    end

                    #
                    # Save the callback and return the promise
                    #
                    @sent_callbacks << [deferred, callback]
                    error = check_result ::Libuv::Ext.udp_send(
                        send_req,
                        handle,
                        buf_init(data),
                        1,
                        sockaddr,
                        callback
                    )
                    if error
                        @sent_callbacks.pop
                        deferred.reject(error)
                        reject(error)       # close the handle
                    end
                rescue StandardError => e
                    deferred.reject(e)
                end
            else
                deferred.reject(RuntimeError.new(HANDLE_CLOSED_ERROR))
            end
            deferred.promise
        end

        def enable_multicast_loop
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_multicast_loop(handle, 1)
            reject(error) if error
        end

        def disable_multicast_loop
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_multicast_loop(handle, 0)
            reject(error) if error
        end

        def multicast_ttl=(ttl)
            return if @closed
            assert_type(Integer, ttl, TTL_ARGUMENT_ERROR)
            error = check_result ::Libuv::Ext.udp_set_multicast_ttl(handle, ttl)
            reject(error) if error
        end

        def enable_broadcast
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_broadcast(handle, 1)
            reject(error) if error
        end

        def disable_broadcast
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_broadcast(handle, 0)
            reject(error) if error
        end

        def ttl=(ttl)
            return if @closed
            assert_type(Integer, ttl, TTL_ARGUMENT_ERROR)
            error = check_result ::Libuv::Ext.udp_set_ttl(handle, Integer(ttl))
            reject(error) if error
        end

        def progress(callback = nil, &blk)
            @progress = callback || blk
        end


        private


        def send_req
            ::Libuv::Ext.create_request(:uv_udp_send)
        end

        def buf_init(data)
            ::Libuv::Ext.buf_init(FFI::MemoryPointer.from_string(data), data.respond_to?(:bytesize) ? data.bytesize : data.size)
        end

        def create_sockaddr(ip, port)
            ips = IPAddr.new(ip)
            if ips.ipv4?
                addr = Ext::SockaddrIn.new
                check_result! ::Libuv::Ext.ip4_addr(ip, port, addr)
                addr
            else
                addr = Ext::SockaddrIn6.new
                check_result! ::Libuv::Ext.ip6_addr(ip, port, addr)
                addr
            end
        end


        def on_close(pointer)
            if @receive_buff
                ::Libuv::Ext.free(@receive_buff)
                @receive_buff = nil
                @receive_size = nil
            end

            super(pointer)
        end

        def on_allocate(client, suggested_size, buffer)
            if @receive_buff.nil?
                @receive_buff = ::Libuv::Ext.malloc(suggested_size)
                @receive_size = suggested_size
            end
            
            buffer[:base] = @receive_buff
            buffer[:len] = @receive_size
        end

        def on_recv(handle, nread, buf, sockaddr, flags)
            e = check_result(nread)

            if e
                reject(e)   # Will call close
            elsif nread > 0
                data = @receive_buff.read_string(nread)
                unless sockaddr.null?
                    ip, port = get_ip_and_port(sockaddr)
                end
                
                begin
                    @progress.call data, ip, port, self
                rescue Exception => e
                    @loop.log :error, :udp_progress_cb, e
                end
            else
                ::Libuv::Ext.free(@receive_buff)
                @receive_buff = nil
                @receive_size = nil
            end
        end
    end
end