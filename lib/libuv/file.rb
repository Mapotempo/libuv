module Libuv
    class File < Q::DeferredPromise
        include Assertions, Resource, Listener, FsChecks


        attr_reader :fileno, :closed


        def initialize(loop, path, flags = 0, mode = 0)
            super(loop, loop.defer)

            @fileno = -1
            @closed = true 
            @path, @flags, @mode = path, flags, mode

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @defer, request, ::Libuv::Ext.fs_open(@loop, request, @path, @flags, @mode, callback(:on_open))
        end

        def close
            @closed = true
            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check(@defer, request, ::Libuv::Ext.fs_close(@loop.handle, request, @fileno, callback(:on_close)))
        end

        def read(length, offset = 0)
            assert_type(Integer, length, "length must be an Integer")
            assert_type(Integer, offset, "offset must be an Integer")
            @read_deferred = @loop.defer

            @read_buffer = FFI::MemoryPointer.new(length)

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check(@read_deferred, request, ::Libuv::Ext.fs_read(@loop.handle, request, @fileno, @read_buffer, length, offset, callback(:on_read)))
            @read_deferred.promise
        end

        def write(data, offset = 0)
            assert_type(String, data, "data must be a String")
            assert_type(Integer, offset, "offset must be an Integer")
            @write_deferred = @loop.defer

            length = data.respond_to?(:bytesize) ? data.bytesize : data.size
            @write_buffer = FFI::MemoryPointer.from_string(data)

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check(@write_deferred, request, ::Libuv::Ext.fs_write(@loop.handle, request, @fileno, @write_buffer, length, offset, callback(:on_write)))
            @write_deferred.promise
        end

        def sync
            @sync_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @sync_deferred, request, ::Libuv::Ext.fs_fsync(@loop.handle, request, @fileno, callback(:on_sync))
            @sync_deferred.promise
        end

        def datasync
            @datasync_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @datasync_deferred, request, ::Libuv::Ext.fs_fdatasync(@loop.handle, request, @fileno, callback(:on_datasync))
            @datasync_deferred.promise
        end

        def truncate(offset)
            assert_type(Integer, offset, "offset must be an Integer")
            @truncate_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @truncate_deferred, request, ::Libuv::Ext.fs_ftruncate(@loop.handle, request, @fileno, offset, callback(:on_truncate))
            @truncate_deferred.promise
        end

        def utime(atime, mtime)
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")
            @utime_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @utime_deferred, request, ::Libuv::Ext.fs_futime(@loop.handle, request, @fileno, atime, mtime, callback(:on_utime))
            @utime_deferred.promise
        end

        def chmod(mode)
            assert_type(Integer, mode, "mode must be an Integer")
            @chmod_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @chmod_deferred, request, ::Libuv::Ext.fs_fchmod(@loop.handle, request, @fileno, mode, callback(:on_chmod))
            @chmod_deferred.promise
        end

        def chown(uid, gid)
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")
            @chown_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @chown_deferred, request, ::Libuv::Ext.fs_fchown(@loop.handle, request, @fileno, uid, gid, callback(:on_chown))
            @chown_deferred.promise
        end


        private


        def on_open(req)
            if post_check(req, @defer)
                @fileno = req[:result]
                cleanup(req)
                @closed = false
                @defer.notify(self)
            end
        end

        def on_close(req)
            if post_check(req, @defer)
                cleanup(req)
                @defer.resolve(nil)
            end
        end

        def on_read(req)
            if post_check(req, @read_deferred)
                data = @read_buffer.read_string(req[:result])
                cleanup(req)
                @read_deferred.resolve(data)
            end
            @read_buffer = nil
            @read_deferred = nil
        end

        def on_write(req)
            if post_check(req, @write_deferred)
                cleanup(req)
                @write_deferred.resolve(nil)
            end
            @write_buffer = nil
            @write_deferred = nil
        end

        def on_sync(req)
            if post_check(req, @sync_deferred)
                cleanup(req)
                @sync_deferred.resolve(nil)
            end
            @sync_deferred = nil
        end

        def on_datasync(req)
            if post_check(req, @datasync_deferred)
                cleanup(req)
                @datasync_deferred.resolve(nil)
            end
            @datasync_deferred = nil
        end

        def on_truncate(req)
            if post_check(req, @truncate_deferred)
                cleanup(req)
                @truncate_deferred.resolve(nil)
            end
            @truncate_deferred = nil
        end

        def on_utime(req)
            if post_check(req, @utime_deferred)
                cleanup(req)
                @utime_deferred.resolve(nil)
            end
            @utime_deferred = nil
        end

        def on_chmod(req)
            if post_check(req, @chmod_deferred)
                cleanup(req)
                @chmod_deferred.resolve(nil)
            end
            @chmod_deferred = nil
        end

        def on_chown(req)
            if post_check(req, @chown_deferred)
                cleanup(req)
                @chown_deferred.resolve(nil)
            end
            @chown_deferred = nil
        end
    end
end