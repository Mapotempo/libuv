require 'ipaddr'


module Libuv
    class TCP < Handle
        include Stream, Net


        def initialize(loop, acceptor = nil)
            tcp_ptr = ::Libuv::Ext.create_handle(:uv_tcp)
            error = check_result(::Libuv::Ext.tcp_init(loop.handle, tcp_ptr))
            error = check_result(::Libuv::Ext.accept(acceptor, tcp_ptr)) if acceptor && error.nil?
            
            super(loop, tcp_ptr, error)
        end

        def bind(ip, port, callback = nil, &blk)
            @on_listen = callback || blk
            assert_type(String, ip, "ip must be a String")
            assert_type(Integer, port, "port must be an Integer")

            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.bind
            rescue Exception => e
                reject(e)
            end
        end

        def accept(callback = nil, &blk)
            tcp = nil
            begin
                tcp = TCP.new(loop, handle)
            rescue Exception => e
                @loop.log :info, :tcp_accept_failed, e
            end
            (callback || blk).call(tcp) if tcp    # Errors here will kill the outer progress loop (this is good)
            nil
        end

        def connect(ip, port, callback = nil, &blk)
            @callback = callback || blk
            assert_type(String, ip, "ip must be a String")
            assert_type(Integer, port, "port must be an Integer")
            
            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.connect(callback(:on_connect))
            rescue Exception => e
                reject(e)
            end
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
            check_result ::Libuv::Ext.tcp_nodelay(handle, 1)
        end

        def disable_nodelay
            check_result ::Libuv::Ext.tcp_nodelay(handle, 0)
        end

        def enable_keepalive(delay)
            assert_type(Integer, delay, "delay must be an Integer")
            check_result ::Libuv::Ext.tcp_keepalive(handle, 1, delay)
        end

        def disable_keepalive
            check_result ::Libuv::Ext.tcp_keepalive(handle, 0, 0)
        end

        def enable_simultaneous_accepts
            check_result ::Libuv::Ext.tcp_simultaneous_accepts(handle, 1)
        end

        def disable_simultaneous_accepts
            check_result ::Libuv::Ext.tcp_simultaneous_accepts(handle, 0)
        end


        private


        def create_socket(ip, port)
            if ip.ipv4?
                Socket4.new(loop, handle, ip.to_s, port)
            else
                Socket6.new(loop, handle, ip.to_s, port)
            end
        end

        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            @callback.call(self)
        end


        class SocketBase
            include Resource

            def initialize(loop, tcp, ip, port)
                @tcp, @sockaddr = tcp, ip_addr(ip, port)
            end

            def bind
                check_result!(tcp_bind)
            end

            def connect(callback)
                check_result!(tcp_connect(callback))
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