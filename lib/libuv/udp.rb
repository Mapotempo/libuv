module Libuv
    class UDP
        include Handle, Net


        def initialize(loop)
            udp_ptr = ::Libuv::Ext.create_handle(:uv_udp)
            super(loop, udp_ptr)
            result = check_result(::Libuv::Ext.udp_init(loop.handle, udp_ptr))
            @handle_deferred.reject(result) if result
        end

        def bind(ip, port, ipv6_only = false)
            begin
                assert_type(String, ip, "ip must be a String")
                assert_type(Integer, port, "port must be an Integer")
                assert_boolean(ipv6_only, "ipv6_only must be a Boolean")

                @socket = create_socket(IPAddr.new(ip), port)
                @socket.bind(ipv6_only)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def sockname
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.udp_getsockname(handle, sockaddr, len)
            get_ip_and_port(UV::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def join(multicast_address, interface_address)
            begin
                assert_type(String, multicast_address, "multicast_address must be a String")
                assert_type(String, interface_address, "interface_address must be a String")

                check_result! ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_join_group)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def leave(multicast_address, interface_address)
            begin
                assert_type(String, multicast_address, "multicast_address must be a String")
                assert_type(String, interface_address, "interface_address must be a String")

                check_result! ::Libuv::Ext.udp_set_membership(handle, multicast_address, interface_address, :uv_leave_group)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def start_recv
            begin
                check_result! ::Libuv::Ext.udp_recv_start(handle, callback(:on_allocate), callback(:on_recv))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def stop_recv
            begin
                check_result! ::Libuv::Ext.udp_recv_stop(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def send(ip, port, data)
            deferred = @loop.defer
            begin
                assert_type(String, ip, "ip must be a String")
                assert_type(Integer, port, "port must be an Integer")
                assert_type(String, data, "data must be a String")

                @socket = create_socket(IPAddr.new(ip), port)

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
                    @socket.send(data, callback)
                rescue Exception => e
                    @sent_callbacks.pop
                    deferred.reject(e)
                end
            rescue Exception => e
                deferred.reject(e)
            end
            deferred.promise
        end

        def enable_multicast_loop
            begin
                check_result! ::Libuv::Ext.udp_set_multicast_loop(handle, 1)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def disable_multicast_loop
            begin
                check_result! ::Libuv::Ext.udp_set_multicast_loop(handle, 0)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def multicast_ttl=(ttl)
            begin
                assert_type(Integer, ttl, "ttl must be an Integer")

                check_result! ::Libuv::Ext.udp_set_multicast_ttl(handle, ttl)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def enable_broadcast
            begin
                check_result! ::Libuv::Ext.udp_set_broadcast(handle, 1)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def disable_broadcast
            begin
                check_result! ::Libuv::Ext.udp_set_broadcast(handle, 0)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def ttl=(ttl)
            begin
                assert_type(Integer, ttl, "ttl must be an Integer")

                check_result! ::Libuv::Ext.udp_set_ttl(handle, Integer(ttl))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end


        private


        def on_allocate(client, suggested_size)
            ::Libuv::Ext.buf_init(::Libuv::Ext.malloc(suggested_size), suggested_size)
        end

        def on_recv(handle, nread, buf, sockaddr, flags)
            e = check_result(nread)
            base = buf[:base]
            unless sockaddr.null?
                ip, port = get_ip_and_port(UV::Sockaddr.new(sockaddr))
            end

            if e
                ::Libuv::Ext.free(base)
                @handle_deferred.reject([e, ip, port])
            else
                data = base.read_string(nread)
                ::Libuv::Ext.free(base)
                @handle_deferred.notify([data, ip, port])   # stream the data
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