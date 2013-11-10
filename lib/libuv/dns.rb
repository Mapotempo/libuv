module Libuv
    class Dns < Q::DeferredPromise
        include Resource, Listener, Net


        attr_reader :results
        attr_reader :domain
        attr_reader :port
        attr_reader :hint


        HINTS = {
            :IPv4 => ::Libuv::Ext::UvAddrinfo.new,
            :IPv6 => ::Libuv::Ext::UvAddrinfo.new
        }
        HINTS[:IPv4].tap do |hint|
            hint[:family] = Socket::Constants::AF_INET
            hint[:socktype] = Socket::Constants::SOCK_STREAM
            hint[:protocol] = Socket::Constants::IPPROTO_TCP
        end
        HINTS[:IPv6].tap do |hint|
            hint[:family] = Socket::Constants::AF_INET6
            hint[:socktype] = Socket::Constants::SOCK_STREAM
            hint[:protocol] = Socket::Constants::IPPROTO_TCP
        end


        # @param loop [::Libuv::Loop] loop this work request will be associated
        # @param domain [String] the domain name to resolve
        # @param port [Integer, String] the port we wish to use
        def initialize(loop, domain, port, hint = :IPv4)
            super(loop, loop.defer)

            @domain = domain
            @port = port
            @hint = hint
            @complete = false
            @pointer = ::Libuv::Ext.create_request(:uv_getaddrinfo)
            @error = nil    # error in callback

            error = check_result ::Libuv::Ext.getaddrinfo(@loop, @pointer, callback(:on_complete), domain, port.to_s, HINTS[hint])
            if error
                ::Libuv::Ext.free(@pointer)
                @complete = true
                @defer.reject(error)
            end
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
            if e
                @defer.reject(e)
            else
                begin
                    current = addrinfo
                    @results = []
                    begin
                        @results << get_ip_and_port(current[:addr])
                        current = current[:next]
                    end while !current.null?
                    @defer.resolve(@results)
                rescue Exception => e
                    @defer.reject(e)
                end
            end

            ::Libuv::Ext.freeaddrinfo(addrinfo)
        end
    end
end