# frozen_string_literal: true

module Libuv
    class Error < StandardError
        class E2BIG < Error; end
        class EACCES < Error; end
        class EADDRINUSE < Error; end
        class EADDRNOTAVAIL < Error; end
        class EAFNOSUPPORT < Error; end
        class EAGAIN < Error; end
        class EAI_ADDRFAMILY < Error; end
        class EAI_AGAIN < Error; end
        class EAI_BADFLAGS < Error; end
        class EAI_BADHINTS < Error; end
        class EAI_CANCELED < Error; end
        class EAI_FAIL < Error; end
        class EAI_FAMILY < Error; end
        class EAI_MEMORY < Error; end
        class EAI_NODATA < Error; end
        class EAI_NONAME < Error; end
        class EAI_OVERFLOW < Error; end
        class EAI_PROTOCOL < Error; end
        class EAI_SERVICE < Error; end
        class EAI_SOCKTYPE < Error; end
        class EALREADY < Error; end
        class EBADF < Error; end
        class EBUSY < Error; end
        class ECANCELED < Error; end
        class ECHARSET < Error; end
        class ECONNABORTED < Error; end
        class ECONNREFUSED < Error; end
        class ECONNRESET < Error; end
        class EDESTADDRREQ < Error; end
        class EEXIST < Error; end
        class EFAULT < Error; end
        class EFBIG < Error; end
        class EHOSTUNREACH < Error; end
        class EINTR < Error; end
        class EINVAL < Error; end
        class EIO < Error; end
        class EISCONN < Error; end
        class EISDIR < Error; end
        class ELOOP < Error; end
        class EMFILE < Error; end
        class EMSGSIZE < Error; end
        class ENAMETOOLONG < Error; end
        class ENETDOWN < Error; end
        class ENETUNREACH < Error; end
        class ENFILE < Error; end
        class ENOBUFS < Error; end
        class ENODEV < Error; end
        class ENOENT < Error; end
        class ENOMEM < Error; end
        class ENONET < Error; end
        class ENOPROTOOPT < Error; end
        class ENOSPC < Error; end
        class ENOSYS < Error; end
        class ENOTCONN < Error; end
        class ENOTDIR < Error; end
        class ENOTEMPTY < Error; end
        class ENOTSOCK < Error; end
        class ENOTSUP < Error; end
        class EPERM < Error; end
        class EPIPE < Error; end
        class EPROTO < Error; end
        class EPROTONOSUPPORT < Error; end
        class EPROTOTYPE < Error; end
        class ERANGE < Error; end
        class EROFS < Error; end
        class ESHUTDOWN < Error; end
        class ESPIPE < Error; end
        class ESRCH < Error; end
        class ETIMEDOUT < Error; end
        class ETXTBSY < Error; end
        class EXDEV < Error; end
        class UNKNOWN < Error; end
        class EOF < Error; end
        class ENXIO < Error; end
        class EMLINK < Error; end
        class EHOSTDOWN < Error; end

        # Non-zero exit code
        class ProcessExitCode < Error
            attr_accessor :exit_status, :term_signal
        end
    end
end
