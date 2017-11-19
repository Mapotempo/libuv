# frozen_string_literal: true

require 'ipaddr'


module Libuv
    class UDP < Handle
        include Net


        define_callback function: :on_allocate, params: [:pointer, :size_t, Ext::UvBuf.by_ref]
        define_callback function: :on_recv, params: [:pointer, :ssize_t, Ext::UvBuf.by_ref, Ext::Sockaddr.by_ref, :uint]
        define_callback function: :send_complete, params: [:pointer, :int]


        SEND_DATA_ERROR = "data must be a String"
        TTL_ARGUMENT_ERROR = "ttl must be an Integer"
        MULTICAST_ARGUMENT_ERROR = "multicast_address must be a String"
        INTERFACE_ARGUMENT_ERROR = "interface_address must be a String"
        HANDLE_CLOSED_ERROR = "unable to send as handle closed"


        def initialize(reactor, progress: nil, flags: nil)
            @reactor = reactor
            @progress = progress

            udp_ptr = ::Libuv::Ext.allocate_handle_udp
            error = if flags
                check_result(::Libuv::Ext.udp_init_ex(reactor.handle, udp_ptr, flags))
            else
                check_result(::Libuv::Ext.udp_init(reactor.handle, udp_ptr))
            end
            @request_refs = {}

            super(udp_ptr, error)
        end

        def bind(ip, port)
            return if @closed
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)

            sockaddr = create_sockaddr(ip, port)
            error = check_result ::Libuv::Ext.udp_bind(handle, sockaddr, 0)
            reject(error) if error

            self
        end

        def open(fd, binding = true)
            return if @closed
            error = check_result ::Libuv::Ext.udp_open(handle, fd)
            reject(error) if error

            self
        end

        def sockname
            return [] if @closed
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.udp_getsockname(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Ext::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def join(multicast_address, interface_address)
            return if @closed
            assert_type(String, multicast_address, MULTICAST_ARGUMENT_ERROR)
            assert_type(String, interface_address, INTERFACE_ARGUMENT_ERROR)

            error = check_result ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_join_group)
            reject(error) if error
            self
        end

        def leave(multicast_address, interface_address)
            return if @closed
            assert_type(String, multicast_address, MULTICAST_ARGUMENT_ERROR)
            assert_type(String, interface_address, INTERFACE_ARGUMENT_ERROR)

            error = check_result ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_leave_group)
            reject(error) if error
            self
        end

        # Starts reading from the handle
        # Renamed to match Stream
        def start_read
            return if @closed
            error = check_result ::Libuv::Ext.udp_recv_start(handle, callback(:on_allocate), callback(:on_recv))
            reject(error) if error
            self
        end

        # Stops reading from the handle
        # Renamed to match Stream
        def stop_read
            return if @closed
            error = check_result ::Libuv::Ext.udp_recv_stop(handle)
            reject(error) if error
            self
        end

        def try_send(ip, port, data)
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)
            assert_type(String, data, SEND_DATA_ERROR)

            sockaddr = create_sockaddr(ip, port)

            buffer1 = ::FFI::MemoryPointer.from_string(data)
            buffer  = ::Libuv::Ext.buf_init(buffer1, data.respond_to?(:bytesize) ? data.bytesize : data.size)

            result = ::Libuv::Ext.udp_try_send(
                handle,
                buffer,
                1,
                sockaddr
            )
            buffer1.free

            error = check_result result
            raise error if error
            return result
        end

        def send(ip, port, data, wait: false)
            # NOTE:: Similar to stream.rb -> write
            deferred = @reactor.defer
            if !@closed
                begin
                    assert_type(String, ip, IP_ARGUMENT_ERROR)
                    assert_type(Integer, port, PORT_ARGUMENT_ERROR)
                    assert_type(String, data, SEND_DATA_ERROR)

                    sockaddr = create_sockaddr(ip, port)

                    # Save a reference to this request
                    req = send_req
                    buffer1 = ::FFI::MemoryPointer.from_string(data)
                    buffer  = ::Libuv::Ext.buf_init(buffer1, data.respond_to?(:bytesize) ? data.bytesize : data.size)
                    @request_refs[req.address] = [deferred, buffer1]

                    # Save the callback and return the promise
                    error = check_result ::Libuv::Ext.udp_send(
                        req,
                        handle,
                        buffer,
                        1,
                        sockaddr,
                        callback(:send_complete, req.address)
                    )
                    if error
                        @request_refs.delete req.address
                        cleanup_callbacks req.address
                        ::Libuv::Ext.free(req)
                        buffer1.free
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

            if wait
                return deferred.promise if wait == :promise
                deferred.promise.value
            end

            self
        end

        def enable_multicast_reactor
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_multicast_reactor(handle, 1)
            reject(error) if error
            self
        end

        def disable_multicast_reactor
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_multicast_reactor(handle, 0)
            reject(error) if error
            self
        end

        def multicast_ttl=(ttl)
            return if @closed
            assert_type(Integer, ttl, TTL_ARGUMENT_ERROR)
            error = check_result ::Libuv::Ext.udp_set_multicast_ttl(handle, ttl)
            reject(error) if error
            self
        end

        def enable_broadcast
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_broadcast(handle, 1)
            reject(error) if error
            self
        end

        def disable_broadcast
            return if @closed
            error = check_result ::Libuv::Ext.udp_set_broadcast(handle, 0)
            reject(error) if error
            self
        end

        def ttl=(ttl)
            return if @closed
            assert_type(Integer, ttl, TTL_ARGUMENT_ERROR)
            error = check_result ::Libuv::Ext.udp_set_ttl(handle, Integer(ttl))
            reject(error) if error
            self
        end

        def progress(&callback)
            @progress = callback
            self
        end


        private


        def send_req
            ::Libuv::Ext.allocate_request_udp_send
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
                @reactor.exec { reject(e) }   # Will call close
            elsif nread > 0
                data = @receive_buff.read_string(nread)
                unless sockaddr.null?
                    ip, port = get_ip_and_port(sockaddr)
                end

                @reactor.exec do
                    begin
                        @progress.call data, ip, port, self
                    rescue Exception => e
                        @reactor.log e, 'performing UDP data received callback'
                    end
                end
            else
                ::Libuv::Ext.free(@receive_buff)
                @receive_buff = nil
                @receive_size = nil
            end
        end

        def send_complete(req, status)
            deferred, buffer1 = @request_refs.delete req.address
            cleanup_callbacks req.address

            ::Libuv::Ext.free(req)
            buffer1.free

            @reactor.exec { resolve(deferred, status) }
        end
    end
end