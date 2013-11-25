require 'ipaddr'
require 'ruby-tls'


module Libuv
    class TCP < Handle
        include Stream, Net


        KEEPALIVE_ARGUMENT_ERROR = "delay must be an Integer".freeze
        TLS_ERROR = "TLS write failed".freeze


        attr_reader :connected


        def initialize(loop, acceptor = nil)
            @loop = loop

            tcp_ptr = ::Libuv::Ext.create_handle(:uv_tcp)
            error = check_result(::Libuv::Ext.tcp_init(loop.handle, tcp_ptr))

            if acceptor && error.nil?
                error = check_result(::Libuv::Ext.accept(acceptor, tcp_ptr))
                @connected = true
            else
                @connected = false
            end
            
            super(tcp_ptr, error)
        end


        #
        # TLS Abstraction ----------------------
        # --------------------------------------
        #
        def start_tls(args = {})
            return unless @connected && @tls.nil?

            @handshake = false
            @pending_writes = []
            @tls = ::RubyTls::Connection.new(self)
            @tls.start(args)
        end

        # Push through any pending writes when handshake has completed
        def handshake_cb
            @handshake = true
            writes = @pending_writes
            @pending_writes = nil
            writes.each do |deferred, data|
                @pending_write = deferred
                @tls.encrypt(data)
            end
        end

        # This is clear text data that has been decrypted
        # Same as stream.rb on_read for clear text
        def dispatch_cb(data)
            begin
                @progress.call data, self
            rescue Exception => e
                @loop.log :error, :stream_progress_cb, e
            end
        end

        # We resolve the existing tls write promise with a the
        #  real writes promise (a close may have occurred)
        def transmit_cb(data)
            if not @pending_write.nil?
                @pending_write.resolve(direct_write(data))
                @pending_write = nil
            else
                direct_write(data)
            end
        end

        # Close can be called multiple times
        def close_cb
            if not @pending_write.nil?
                @pending_write.reject(TLS_ERROR)
                @pending_write = nil
            end

            # Shutdown the stream
            close
        end

        # overwrite the default close to ensure
        # pending writes are rejected
        def close
            @connected = false

            if not @pending_writes.nil?
                @pending_writes.each do |deferred, data|
                    deferred.reject(TLS_ERROR)
                end
                @pending_writes = nil
            end

            super
        end

        # Verify peers will be called for each cert in the chain
        def verify_peer(&block)
            @tls.verify_cb &block
        end

        alias_method :direct_write, :write
        def write(data)
            if @tls.nil?
                direct_write(data)
            else
                deferred = @loop.defer
                
                if @handshake == true
                    @pending_write = deferred
                    @tls.encrypt(data)
                else
                    @pending_writes << [deferred, data]
                end

                deferred.promise
            end
        end
        #
        # END TLS Abstraction ------------------
        # --------------------------------------
        #

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
            get_ip_and_port(::Libuv::Ext::Sockaddr.new(sockaddr), len.get_int(0))
        end

        def peername
            return [] if @closed
            sockaddr, len = get_sockaddr_and_len
            check_result! ::Libuv::Ext.tcp_getpeername(handle, sockaddr, len)
            get_ip_and_port(::Libuv::Ext::Sockaddr.new(sockaddr), len.get_int(0))
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
            @connected = true

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