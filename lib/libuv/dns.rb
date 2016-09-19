# frozen_string_literal: true

module Libuv
    class Dns < Q::DeferredPromise
        include Resource, Listener, Net


        define_callback function: :on_complete, params: [:pointer, :int, Ext::UvAddrinfo.by_ref]


        attr_reader :results
        attr_reader :domain
        attr_reader :port
        attr_reader :hint


        HINTS = {
            :IPv4 => ::Libuv::Ext::UvAddrinfo.new,
            :IPv6 => ::Libuv::Ext::UvAddrinfo.new
        }
        HINTS[:IPv4].tap do |hint|
            hint[:family] = FFI::Platform.windows? ? 2 : Socket::Constants::AF_INET
            hint[:socktype] = Socket::Constants::SOCK_STREAM
            hint[:protocol] = Socket::Constants::IPPROTO_TCP
        end
        HINTS[:IPv6].tap do |hint|
            hint[:family] = FFI::Platform.windows? ? 23 : Socket::Constants::AF_INET6
            hint[:socktype] = Socket::Constants::SOCK_STREAM
            hint[:protocol] = Socket::Constants::IPPROTO_TCP
        end


        # @param reactor [::Libuv::Reactor] reactor this work request will be associated
        # @param domain [String] the domain name to resolve
        # @param port [Integer, String] the port we wish to use
        def initialize(reactor, domain, port, hint = :IPv4, wait: true)
            super(reactor, reactor.defer)

            @domain = domain
            @port = port
            @hint = hint
            @complete = false
            @pointer = ::Libuv::Ext.allocate_request_getaddrinfo
            @error = nil    # error in callback

            @instance_id = @pointer.address
            error = check_result ::Libuv::Ext.getaddrinfo(@reactor, @pointer, callback(:on_complete), domain, port.to_s, HINTS[hint])

            if error
                ::Libuv::Ext.free(@pointer)
                @complete = true
                @defer.reject(error)
            end

            co(@defer.promise) if wait
        end

        # Indicates if the lookup has completed yet or not.
        #
        # @return [true, false]
        def completed?
            return @complete
        end


        private


        def on_complete(req, status, addrinfo)
            @complete = true
            ::Libuv::Ext.free(req)

            e = check_result(status)

            ::Fiber.new { 
                if e
                    @defer.reject(e)
                else
                    begin
                        current = addrinfo
                        @results = []
                        while !current.null?
                            @results << get_ip_and_port(current[:addr])
                            current = current[:next]
                        end
                        @defer.resolve(@results)
                    rescue Exception => e
                        @defer.reject(e)
                    end
                    ::Libuv::Ext.freeaddrinfo(addrinfo)
                end
            }.resume

            # Clean up references
            cleanup_callbacks
        end
    end
end