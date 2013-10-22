require 'ipaddr'


module Libuv
    class TCP < Handle
        include Stream, Net


        KEEPALIVE_ARGUMENT_ERROR = "delay must be an Integer".freeze


        def initialize(loop, acceptor = nil)
            @loop = loop

            tcp_ptr = ::Libuv::Ext.create_handle(:uv_tcp)
            error = check_result(::Libuv::Ext.tcp_init(loop.handle, tcp_ptr))
            error = check_result(::Libuv::Ext.accept(acceptor, tcp_ptr)) if acceptor && error.nil?
            
            super(tcp_ptr, error)
        end

        def bind(ip, port, callback = nil, &blk)
            return if @closed
            @on_listen = callback || blk
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)

            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.bind
            rescue Exception => e
                reject(e)
            end
        end

        def open(fd, binding = true, callback = nil, &blk)
            return if @closed
            if binding
                @on_listen = callback || blk
            else
                @callback = callback || blk
            end
            error = check_result UV.tcp_open(handle, fd)
            reject(error) if error
        end

        def accept(callback = nil, &blk)
            begin
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
                tcp = TCP.new(loop, handle)
                begin
                    (callback || blk).call(tcp)
                rescue Exception => e
                    @loop.log :error, :tcp_accept_cb, e
                end
            rescue Exception => e
                @loop.log :info, :tcp_accept_failed, e
            end
            nil
        end

        def connect(ip, port, callback = nil, &blk)
            return if @closed
            @callback = callback || blk
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)
            
            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.connect(callback(:on_connect))
            rescue Exception => e
                reject(e)
            end
        end

        def sockname
            return [] if @closed
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.tcp_getsockname(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def peername
            return [] if @closed
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.tcp_getpeername(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def enable_nodelay
            return if @closed
            check_result ::Libuv::Ext.tcp_nodelay(handle, 1)
        end

        def disable_nodelay
            return if @closed
            check_result ::Libuv::Ext.tcp_nodelay(handle, 0)
        end

        def enable_keepalive(delay)
            return if @closed
            assert_type(Integer, delay, KEEPALIVE_ARGUMENT_ERROR)
            check_result ::Libuv::Ext.tcp_keepalive(handle, 1, delay)
        end

        def disable_keepalive
            return if @closed
            check_result ::Libuv::Ext.tcp_keepalive(handle, 0, 0)
        end

        def enable_simultaneous_accepts
            return if @closed
            check_result ::Libuv::Ext.tcp_simultaneous_accepts(handle, 1)
        end

        def disable_simultaneous_accepts
            return if @closed
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
            begin
                @callback.call(self)
            rescue Exception => e
                @loop.log :error, :connect_cb, e
            end
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


            protected


            def connect_req
                ::Libuv::Ext.create_request(:uv_connect)
            end

            def tcp_connect(callback)
                ::Libuv::Ext.tcp_connect(
                  connect_req,
                  @tcp,
                  @sockaddr,
                  callback
                )
            end

            def tcp_bind
                ::Libuv::Ext.tcp_bind(@tcp, @sockaddr)
            end
        end


        class Socket4 < SocketBase
            protected


            def ip_addr(ip, port)
                addr = Ext::SockaddrIn.new
                check_result! ::Libuv::Ext.ip4_addr(ip, port, addr)
                addr
            end
        end


        class Socket6 < SocketBase
            protected


            def ip_addr(ip, port)
                addr = Ext::SockaddrIn6.new
                check_result! ::Libuv::Ext.ip6_addr(ip, port, addr)
                addr
            end
        end
    end
end