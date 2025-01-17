# frozen_string_literal: true

module MTLibuv
    class Dns < Q::DeferredPromise
        include Resource, Listener, Net


        define_callback function: :on_complete, params: [:pointer, :int, Ext::UvAddrinfo.by_ref]


        attr_reader :results
        attr_reader :domain
        attr_reader :port
        attr_reader :hint


        HINTS = {
            :IPv4 => ::MTLibuv::Ext::UvAddrinfo.new,
            :IPv6 => ::MTLibuv::Ext::UvAddrinfo.new
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


        # @param reactor [::MTLibuv::Reactor] reactor this work request will be associated
        # @param domain [String] the domain name to resolve
        # @param port [Integer, String] the port we wish to use
        def initialize(reactor, domain, port, hint = :IPv4, wait: true)
            super(reactor, reactor.defer)

            @domain = domain
            @port = port
            @hint = hint
            @complete = false
            @pointer = ::MTLibuv::Ext.allocate_request_getaddrinfo
            @error = nil    # error in callback

            @instance_id = @pointer.address
            error = check_result ::MTLibuv::Ext.getaddrinfo(@reactor, @pointer, callback(:on_complete), domain, port.to_s, HINTS[hint])

            if error
                ::MTLibuv::Ext.free(@pointer)
                @complete = true
                @defer.reject(error)
            end

            @defer.promise.value if wait
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
            ::MTLibuv::Ext.free(req)

            e = check_result(status)

            @reactor.exec do
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
                    ::MTLibuv::Ext.freeaddrinfo(addrinfo)
                end
            end

            # Clean up references
            cleanup_callbacks
        end
    end
end