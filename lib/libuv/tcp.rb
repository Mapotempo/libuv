require 'ipaddr'


module Libuv
    class TCP < Handle
        include Stream, Net


        def self.accept(loop, handle)
            p "#{handle.inspect}"
            AcceptTCP.new(loop, handle)
        end


        def initialize(loop)
            tcp_ptr = ::Libuv::Ext.create_handle(:uv_tcp)
            result = check_result(::Libuv::Ext.tcp_init(loop.handle, tcp_ptr))
            
            if result
                super(loop, tcp_ptr, result, true)
            else
                super(loop, tcp_ptr, self, false)
            end
        end

        def reuse(loop)
            result = check_result(::Libuv::Ext.tcp_init(loop.handle, @pointer))
            
            # reset promise
            if result.nil?
                @response = self
                @error = false
            else
                @response = result
                @error = true
            end

            @loop = loop
            @handle_deferred = nil
        end

        def bind(ip, port)
            @handle_deferred, @binding = create_socket(IPAddr.new(ip), port)
            begin
                assert_type(String, ip, "ip must be a String")
                assert_type(Integer, port, "port must be an Integer")

                @binding.bind   # @handle_deferred is a SocketBase < Promise
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @binding
        end

        def connect(ip, port, callback = nil, &blk)
            @callback = callback || blk
            @handle_deferred, @binding = create_socket(IPAddr.new(ip), port)
            begin
                assert_type(String, ip, "ip must be a String")
                assert_type(Integer, port, "port must be an Integer")

                @binding.connect(callback(:on_connect))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @binding
        end

        def sockname
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.tcp_getsockname(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def peername
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.tcp_getpeername(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def enable_nodelay
            check_result! ::Libuv::Ext.tcp_nodelay(handle, 1)
            self
        end

        def disable_nodelay
            check_result! ::Libuv::Ext.tcp_nodelay(handle, 0)
            self
        end

        def enable_keepalive(delay)
            assert_type(Integer, delay, "delay must be an Integer")
            check_result! ::Libuv::Ext.tcp_keepalive(handle, 1, delay)
            self
        end

        def disable_keepalive
            check_result! ::Libuv::Ext.tcp_keepalive(handle, 0, 0)
            self
        end

        def enable_simultaneous_accepts
            check_result! ::Libuv::Ext.tcp_simultaneous_accepts(handle, 1)
            self
        end

        def disable_simultaneous_accepts
            check_result! ::Libuv::Ext.tcp_simultaneous_accepts(handle, 0)
            self
        end


        private


        def create_socket(ip, port)
            deferred = @loop.defer
            if ip.ipv4?
                prom = Socket4.new(@loop, deferred, handle, ip.to_s, port)
            else
                prom = Socket6.new(@loop, deferred, handle, ip.to_s, port)
            end
            return deferred, prom
        end

        def on_connect(req, status)
            p 'connect callback'

            ::Libuv::Ext.free(req)
            @callback.call(self)
        end


        # Special class for accepting TCP streams
        class AcceptTCP < TCP
            private :bind
            private :connect
            private :enable_simultaneous_accepts
            private :disable_simultaneous_accepts


            def initialize(loop, handle)
                @pointer = ::Libuv::Ext.create_handle(:uv_tcp)
                result = check_result(::Libuv::Ext.tcp_init(loop.handle, @pointer))
                result = check_result(::Libuv::Ext.accept(handle, @pointer))

                # init promise
                if result.nil?
                    @handle_deferred = loop.defer                   # The stream
                    @response = {:handle => self, :binding => @handle_deferred.promise}    # Passes the promise object in the response
                    @error = false
                else
                    @response = result
                    @error = true
                end
                @defer = loop.defer
                @loop = loop
            end
        end


        class SocketBase < Q::DeferredPromise
            include Resource

            def initialize(loop, deferred, tcp, ip, port)
                @tcp, @sockaddr = tcp, ip_addr(ip, port)

                # Initialise the promise
                super(loop, deferred)
            end

            def bind
                result = check_result(tcp_bind)
                reject(result) if result
            end

            def connect(callback)
                result = check_result(tcp_connect(callback))
                reject(result) if result
            end


            private


            def connect_req
                ::Libuv::Ext.create_request(:uv_connect)
            end
        end

        class Socket4 < SocketBase


            private


            def ip_addr(ip, port)
                ::Libuv::Ext.ip4_addr(ip, port)
            end

            def tcp_bind
                ::Libuv::Ext.tcp_bind(@tcp, @sockaddr)
            end

            def tcp_connect(callback)
                ::Libuv::Ext.tcp_connect(
                  connect_req,
                  @tcp,
                  @sockaddr,
                  callback
                )
            end
        end

        class Socket6 < SocketBase


            private


            def ip_addr(ip, port)
                ::Libuv::Ext.ip6_addr(ip, port)
            end

            def tcp_bind
                ::Libuv::Ext.tcp_bind6(@tcp, @sockaddr)
            end

            def tcp_connect(callback)
                ::Libuv::Ext.tcp_connect6(
                  connect_req,
                  @tcp,
                  @sockaddr,
                  callback
                )
            end
        end
    end
end