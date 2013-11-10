module Libuv
    module Ext
        typedef :int, :uv_os_sock_t
        
        class UvBuf < FFI::Struct
            layout :base, :pointer, :len, :size_t
        end

        class UvFSStat < FFI::Struct
            layout  :st_dev, :dev_t, :st_ino, :ino_t, :st_mode, :mode_t, :st_nlink, :nlink_t,
                    :st_uid, :uid_t, :st_gid, :gid_t, :st_rdev, :dev_t, :st_size, :off_t,
                    :st_blksize, :blksize_t, :st_blocks, :blkcnt_t, :st_atime, :time_t,
                    :st_mtime, :time_t, :st_ctime, :time_t
        end

        class UvAddrinfo < FFI::Struct
            layout  :flags, :int,
                    :family, :int,
                    :socktype, :int,
                    :protocol, :int,
                    :addrlen, :socklen_t,
                    :addr, Sockaddr.by_ref,
                    :canonname, :string,
                    :next, UvAddrinfo.by_ref
        end

        attach_function :ntohs, [:ushort], :ushort, :blocking => true
    end
end
