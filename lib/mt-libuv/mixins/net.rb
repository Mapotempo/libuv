# frozen_string_literal: true

require 'socket'

module MTLibuv
    module Net


        IP_ARGUMENT_ERROR = "ip must be a String"                # Arguments specifying an IP address
        PORT_ARGUMENT_ERROR = "port must be an Integer"          # Arguments specifying an IP port
        INET_ADDRSTRLEN = 16
        INET6_ADDRSTRLEN = 46


        private


        def get_sockaddr_and_len
            sockaddr = FFI::MemoryPointer.new(::MTLibuv::Ext::Sockaddr)
            len = FFI::MemoryPointer.new(:int)
            len.put_int(0, ::MTLibuv::Ext::Sockaddr.size)
            [sockaddr, len]
        end

        def get_ip_and_port(sockaddr, len = nil)
            if sockaddr[:sa_family] == Socket::Constants::AF_INET6
                len ||= INET6_ADDRSTRLEN
                sockaddr_in6 = ::MTLibuv::Ext::SockaddrIn6.new(sockaddr.pointer)
                ip_ptr = FFI::MemoryPointer.new(:char, len)
                ::MTLibuv::Ext.ip6_name(sockaddr_in6, ip_ptr, len)
                port = ::MTLibuv::Ext.ntohs(sockaddr_in6[:sin6_port])
            else
                len ||= INET_ADDRSTRLEN
                sockaddr_in = ::MTLibuv::Ext::SockaddrIn.new(sockaddr.pointer)
                ip_ptr = FFI::MemoryPointer.new(:char, len)
                ::MTLibuv::Ext.ip4_name(sockaddr_in, ip_ptr, len)
                port = ::MTLibuv::Ext.ntohs(sockaddr_in[:sin_port])
            end
            [ip_ptr.read_string, port]
        end
    end
end
