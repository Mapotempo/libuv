module Libuv
    class File
        include Assertions, Resource, Listener


        def initialize(loop, fd)
            @loop = loop
            @fd = Integer(fd)
        end

        def close
            begin
                @close_deferred = @loop.defer
                check_result! ::Libuv::Ext.fs_close(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_close))
            rescue Exception => e
                @close_deferred.reject(e)
            ensure
                @close_deferred.promise
            end
        end

        def read(length, offset = 0)
            begin
                @read_deferred = @loop.defer
                assert_type(Integer, length, "length must be an Integer")
                assert_type(Integer, offset, "offset must be an Integer")

                @read_block         = block
                @read_buffer_length = length
                @read_buffer        = FFI::MemoryPointer.new(@read_buffer_length)

                check_result! ::Libuv::Ext.fs_read(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, @read_buffer, @read_buffer_length, offset, callback(:on_read))
            rescue Exception => e
                @read_deferred.reject(e)
            ensure
                @read_deferred.promise
            end
        end

        def write(data, offset = 0)
            begin
                @write_deferred = @loop.defer
                assert_type(String, data, "data must be a String")
                assert_type(Integer, offset, "offset must be an Integer")

                @write_block = block
                @write_buffer_length = data.respond_to?(:bytesize) ? data.bytesize : data.size
                @write_buffer = FFI::MemoryPointer.from_string(data)

                check_result! ::Libuv::Ext.fs_write(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, @write_buffer, @write_buffer_length, offset, callback(:on_write))
            rescue Exception => e
                @write_deferred.reject(e)
            ensure
                @write_deferred.promise
            end
        end

        def stat
            begin
                @stat_deferred = @loop.defer
                check_result! ::Libuv::Ext.fs_fstat(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_stat))
            rescue Exception => e
                @sync_deferred.reject(e)
            ensure
                @sync_deferred.promise
            end
        end

        def sync
            begin
                @sync_deferred = @loop.defer
                check_result! ::Libuv::Ext.fs_fsync(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_sync))
            rescue Exception => e
                @sync_deferred.reject(e)
            ensure
                @sync_deferred.promise
            end
        end

        def datasync
            begin
                @datasync_deferred = @loop.defer
                check_result! ::Libuv::Ext.fs_fdatasync(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_datasync))
            rescue Exception => e
                @datasync_deferred.reject(e)
            ensure
                @datasync_deferred.promise
            end
        end

        def truncate(offset)
            begin
                @truncate_deferred = @loop.defer
                assert_type(Integer, offset, "offset must be an Integer")

                check_result! ::Libuv::Ext.fs_ftruncate(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, offset, callback(:on_truncate))
            rescue Exception => e
                @truncate_deferred.reject(e)
            ensure
                @truncate_deferred.promise
            end
        end

        def utime(atime, mtime)
            begin
                @utime_deferred = @loop.defer
                assert_type(Integer, atime, "atime must be an Integer")
                assert_type(Integer, mtime, "mtime must be an Integer")

                check_result! ::Libuv::Ext.fs_futime(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, atime, mtime, callback(:on_utime))
            rescue Exception => e
                @utime_deferred.reject(e)
            ensure
                @utime_deferred.promise
            end
        end

        def chmod(mode)
            begin
                @chmod_deferred = @loop.defer
                assert_type(Integer, mode, "mode must be an Integer")
                check_result! ::Libuv::Ext.fs_fchmod(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, mode, callback(:on_chmod))
            rescue Exception => e
                @chmod_deferred.reject(e)
            ensure
                @chmod_deferred.promise
            end
        end

        def chown(uid, gid)
            begin
                @chown_deferred = @loop.defer
                assert_type(Integer, uid, "uid must be an Integer")
                assert_type(Integer, gid, "gid must be an Integer")

                check_result! ::Libuv::Ext.fs_fchown(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, uid, gid, callback(:on_chown))
            rescue Exception => e
                @chown_deferred.reject(e)
            ensure
                @chown_deferred.promise
            end
        end


        private


        def on_close(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @close_deferred.resolve(nil)
            @close_deferred = nil
        end

        def on_read(req)
            data = @read_buffer.read_string(@read_buffer_length)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @read_buffer = nil
            @read_buffer_length = nil
            @read_deferred.resolve(data)
            @read_deferred = nil
        end

        def on_write(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @write_buffer = nil
            @write_buffer_length = nil
            
            @write_deferred.resolve(nil)
            @write_deferred = nil
        end

        def on_stat(req)
            # TODO:: doesn't currently grab any stats
            #unless e
            #    uv_stat    = ::Libuv::Ext.fs_req_stat(req)
            #    uv_members = uv_stat.members
            #
            #    values = Stat.members.map { |k| uv_members.include?(k) ? uv_stat[k] : nil }
            #    stat = Stat.new(*values)
            #end
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @stat_deferred.resolve(nil)
            @stat_deferred = nil
        end

        def on_sync(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @sync_deferred.resolve(nil)
            @sync_deferred = nil
        end

        def on_datasync(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @datasync_deferred.resolve(nil)
            @datasync_deferred = nil
        end

        def on_truncate(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @truncate_deferred.resolve(nil)
            @truncate_deferred = nil
        end

        def on_utime(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @utime_deferred.resolve(nil)
            @utime_deferred = nil
        end

        def on_chmod(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @chmod_deferred.resolve(nil)
            @chmod_deferred = nil
        end

        def on_chown(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @chown_deferred.resolve(nil)
            @chmod_deferred = nil
        end
    end
end