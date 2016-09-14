# frozen_string_literal: true

require 'ipaddr'
require 'ruby-tls'


module Libuv
    class TCP < Handle
        include Stream, Net


        define_callback function: :on_connect, params: [:pointer, :int]


        TLS_ERROR = "TLS write failed".freeze


        attr_reader :connected
        attr_reader :protocol

        # Check if tls active on the socket
        def tls?; !@tls.nil?; end


        def initialize(reactor, acceptor = nil, progress: nil)
            @reactor = reactor
            @progress = progress

            tcp_ptr = ::Libuv::Ext.allocate_handle_tcp
            error = check_result(::Libuv::Ext.tcp_init(reactor.handle, tcp_ptr))

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
            return self unless @connected && @tls.nil?

            args[:verify_peer] = true if @on_verify

            @handshake = false
            @pending_writes = []
            @tls = ::RubyTls::SSL::Box.new(args[:server], self, args)
            @tls.start
            self
        end

        # Push through any pending writes when handshake has completed
        def handshake_cb(protocol = nil)
            @handshake = true
            @protocol = protocol

            writes = @pending_writes
            @pending_writes = nil
            writes.each do |deferred, data|
                @pending_write = deferred
                @tls.encrypt(data)
            end

            begin
                @on_handshake.call(self, protocol) if @on_handshake
            rescue => e
                @reactor.log e, 'performing TLS handshake callback'
            end
        end

        # Provide a callback once the TLS handshake has completed
        def on_handshake(callback = nil, &blk)
            @on_handshake = callback || blk
            self
        end

        # This is clear text data that has been decrypted
        # Same as stream.rb on_read for clear text
        def dispatch_cb(data)
            begin
                @progress.call data, self
            rescue Exception => e
                @reactor.log e, 'performing TLS read data callback'
            end
        end

        # We resolve the existing tls write promise with a the
        #  real writes promise (a close may have occurred)
        def transmit_cb(data)
            if @pending_write
                @pending_write.resolve(direct_write(data))
                @pending_write = nil
            else
                direct_write(data)
            end
        end

        # Close can be called multiple times
        def close_cb
            if @pending_write
                @pending_write.reject(TLS_ERROR)
                @pending_write = nil
            end

            # Shutdown the stream
            close
        end

        def verify_cb(cert)
            if @on_verify
                begin
                    return @on_verify.call cert
                rescue => e
                    @reactor.log e, 'performing TLS verify callback'
                    return false
                end
            end

            true
        end

        # overwrite the default close to ensure
        # pending writes are rejected
        def close
            return self if @closed

            # Free tls memory
            # Next tick as may recieve data after closing
            if @tls
                @reactor.next_tick do
                    @tls.cleanup
                end
            end
            @connected = false

            if @pending_writes
                @pending_writes.each do |deferred, data|
                    deferred.reject(TLS_ERROR)
                end
                @pending_writes = nil
            end

            super
        end

        # Verify peers will be called for each cert in the chain
        def verify_peer(callback = nil, &blk)
            @on_verify = callback || blk
            self
        end

        alias_method :direct_write, :write
        def write(data, wait: false)
            if @tls
                deferred = @reactor.defer
                
                if @handshake
                    @pending_write = deferred
                    @tls.encrypt(data)
                else
                    @pending_writes << [deferred, data]
                end

                if wait
                    return deferred.promise if wait == :promise
                    co deferred.promise
                end

                self
            else
                direct_write(data, wait: wait)
            end
        end

        alias_method :do_shutdown, :shutdown
        def shutdown
            if @pending_writes && @pending_writes.length > 0
                @pending_writes[-1][0].finally method(:do_shutdown)
            else
                do_shutdown
            end
            self
        end
        #
        # END TLS Abstraction ------------------
        # --------------------------------------
        #

        def bind(ip, port, callback = nil, &blk)
            return self if @closed

            @on_accept = callback || blk
            @on_listen = method(:accept)

            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)

            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.bind
            rescue Exception => e
                reject(e)
            end

            self
        end

        def open(fd, binding = true, callback = nil, &blk)
            return self if @closed

            if binding
                @on_listen = method(:accept)
                @on_accept = callback || blk
            else
                @callback = callback || blk
                @coroutine = @reactor.defer if @callback.nil?
            end
            error = check_result UV.tcp_open(handle, fd)
            reject(error) if error
            co @coroutine.promise if @coroutine

            self
        end

        def connect(ip, port, callback = nil, &blk)
            return self if @closed

            @callback = callback || blk
            assert_type(String, ip, IP_ARGUMENT_ERROR)
            assert_type(Integer, port, PORT_ARGUMENT_ERROR)
            
            begin
                @tcp_socket = create_socket(IPAddr.new(ip), port)
                @tcp_socket.connect(callback(:on_connect, @tcp_socket.connect_req.address))
            rescue Exception => e
                reject(e)
            end

            if @callback.nil?
                @coroutine = @reactor.defer
                co @coroutine.promise
            end

            self
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
            return self if @closed
            check_result ::Libuv::Ext.tcp_nodelay(handle, 1)
            self
        end

        def disable_nodelay
            return self if @closed
            check_result ::Libuv::Ext.tcp_nodelay(handle, 0)
            self
        end

        def enable_keepalive(delay)
            return self if @closed                   # The to_i asserts integer
            check_result ::Libuv::Ext.tcp_keepalive(handle, 1, delay.to_i)
            self
        end

        def disable_keepalive
            return self if @closed
            check_result ::Libuv::Ext.tcp_keepalive(handle, 0, 0)
            self
        end

        def enable_simultaneous_accepts
            return self if @closed
            check_result ::Libuv::Ext.tcp_simultaneous_accepts(handle, 1)
            self
        end

        def disable_simultaneous_accepts
            return self if @closed
            check_result ::Libuv::Ext.tcp_simultaneous_accepts(handle, 0)
            self
        end


        private


        def create_socket(ip, port)
            if ip.ipv4?
                Socket4.new(reactor, handle, ip.to_s, port)
            else
                Socket6.new(reactor, handle, ip.to_s, port)
            end
        end

        def on_connect(req, status)
            cleanup_callbacks req.address
            ::Libuv::Ext.free(req)
            e = check_result(status)

            ::Fiber.new {
                if e
                    reject(e)
                else
                    @connected = true

                    begin
                        if @callback
                            @callback.call(self)
                            @callback = nil
                        elsif @coroutine
                            @coroutine.resolve(nil)
                            @coroutine = nil
                        else
                            raise ArgumentError, 'no callback provided'
                        end
                    rescue Exception => e
                        @reactor.log e, 'performing TCP connection callback'
                    end
                end
            }.resume
        end

        def accept(_)
            begin
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
                tcp = TCP.new(reactor, handle)

                ::Fiber.new {
                    begin
                        @on_accept.call(tcp)
                    rescue Exception => e
                        @reactor.log e, 'performing TCP accept callback'
                    end
                }.resume
            rescue Exception => e
                @reactor.log e, 'failed to accept TCP connection'
            end
        end


        class SocketBase
            include Resource

            def initialize(reactor, tcp, ip, port)
                @ip = ip
                @port = port
                @tcp = tcp
                @reactor = reactor
                @req = ::Libuv::Ext.allocate_request_connect
            end

            def bind
                check_result! ::Libuv::Ext.tcp_bind(@tcp, ip_addr)
            end

            def connect(callback)
                @callback = callback
                check_result!(tcp_connect)
            end

            def connect_req
                @req
            end


            protected


            def tcp_connect
                ::Libuv::Ext.tcp_connect(
                  @req,
                  @tcp,
                  ip_addr,
                  @callback
                )
            end
        end


        class Socket4 < SocketBase
            protected


            def ip_addr
                @sockaddr = Ext::SockaddrIn.new
                check_result! ::Libuv::Ext.ip4_addr(@ip, @port, @sockaddr)
                @sockaddr
            end
        end


        class Socket6 < SocketBase
            protected


            def ip_addr
                @sockaddr = Ext::SockaddrIn6.new
                check_result! ::Libuv::Ext.ip6_addr(@ip, @port, @sockaddr)
                @sockaddr
            end
        end
    end
end
