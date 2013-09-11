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

        def bind(ip, port, ipv6_only = false)
            return if @closed
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)

            begin
                @udp_socket = create_socket(IPAddr.new(ip), port)
                @udp_socket.bind(ipv6_only)
            rescue Exception => e
                reject(e)
            end
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

        def start_recv
            return if @closed
            error = check_result ::Libuv::Ext.udp_recv_start(handle, callback(:on_allocate), callback(:on_recv))
            reject(error) if error
        end

        def stop_recv
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

                    @udp_socket = create_socket(IPAddr.new(ip), port)

                    # local as this variable will be avaliable until the handle is closed
                    @sent_callbacks = @sent_callbacks || []

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
                    begin
                        @sent_callbacks << [deferred, callback]
                        @udp_socket.send(data, callback)
                    rescue Exception => e
                        @sent_callbacks.pop
                        deferred.reject(e)

                        reject(e)       # close the handle
                    end
                rescue Exception => e
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


        private


        def on_allocate(client, suggested_size, buf)
            buf.write_pointer ::Libuv::Ext.buf_init(::Libuv::Ext.malloc(suggested_size), suggested_size)
        end

        def on_recv(handle, nread, buf, sockaddr, flags)
            e = check_result(nread)
            base = buf[:base]

            if e
                ::Libuv::Ext.free(base)
                reject(e)
            else
                data = base.read_string(nread)
                ::Libuv::Ext.free(base)
                unless sockaddr.null?
                    ip, port = get_ip_and_port(UV::Sockaddr.new(sockaddr))
                end
                defer.notify(data, ip, port)   # stream the data
            end
        end

        def create_socket(ip, port)
            if ip.ipv4?
                Socket4.new(@loop, handle, ip, port)
            else
                Socket6.new(@loop, handle, ip, port)
            end
        end


        module SocketMethods
            include Resource

            def initialize(loop, udp, ip, port)
                @loop, @udp, @sockaddr = loop, udp, ip_addr(ip.to_s, port)
            end

            def bind(ipv6_only = false)
                check_result! udp_bind(ipv6_only)
            end

            def send(data, callback)
                check_result! udp_send(data, callback)
            end


            private


            def send_req
                ::Libuv::Ext.create_request(:uv_udp_send)
            end

            def buf_init(data)
                ::Libuv::Ext.buf_init(FFI::MemoryPointer.from_string(data), data.respond_to?(:bytesize) ? data.bytesize : data.size)
            end
        end


        class Socket4
            include SocketMethods


            private


            def ip_addr(ip, port)
                ::Libuv::Ext.ip4_addr(ip, port)
            end

            def udp_bind(ipv6_only)
                ::Libuv::Ext.udp_bind(@udp, @sockaddr, 0)
            end

            def udp_send(data, callback)
                ::Libuv::Ext.udp_send(
                    send_req,
                    @udp,
                    buf_init(data),
                    1,
                    @sockaddr,
                    callback
                )
            end
        end


        class Socket6 < Socket
            include SocketMethods


            private


            def ip_addr(ip, port)
                ::Libuv::Ext.ip6_addr(ip, port)
            end

            def udp_bind(ipv6_only)
                ::Libuv::Ext.udp_bind6(@udp, @sockaddr, ipv6_only ? 1 : 0)
            end

            def udp_send(data, callback)
                ::Libuv::Ext.udp_send6(
                    send_req,
                    @udp,
                    buf_init(data),
                    1,
                    @sockaddr,
                    callback
                )
            end
        end
    end
end