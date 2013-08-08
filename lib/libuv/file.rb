module Libuv
    class File
        include Assertions, Resource, Listener


        def initialize(loop, fd)
            @loop = loop
            @fd = Integer(fd)
        end

        def close(&block)
            assert_block(block)
            assert_arity(1, block)

            @close_block = block
            check_result! ::Libuv::Ext.fs_close(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_close))

            self
        end

        def read(length, offset = 0, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(Integer, length, "length must be an Integer")
            assert_type(Integer, offset, "offset must be an Integer")

            @read_block         = block
            @read_buffer_length = length
            @read_buffer        = FFI::MemoryPointer.new(@read_buffer_length)

            check_result! ::Libuv::Ext.fs_read(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, @read_buffer, @read_buffer_length, offset, callback(:on_read))

            self
        end

        def write(data, offset = 0, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, data, "data must be a String")
            assert_type(Integer, offset, "offset must be an Integer")

            @write_block = block
            @write_buffer_length = data.respond_to?(:bytesize) ? data.bytesize : data.size
            @write_buffer = FFI::MemoryPointer.from_string(data)

            check_result! ::Libuv::Ext.fs_write(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, @write_buffer, @write_buffer_length, offset, callback(:on_write))

            self
        end

        def stat(&block)
            assert_block(block)
            assert_arity(2, block)

            @stat_block = block
            check_result! ::Libuv::Ext.fs_fstat(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_stat))

            self
        end

        def sync(&block)
            assert_block(block)
            assert_arity(1, block)

            @sync_block = block
            check_result! ::Libuv::Ext.fs_fsync(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_sync))

            self
        end

        def datasync(&block)
            assert_block(block)
            assert_arity(1, block)

            @datasync_block = block
            check_result! ::Libuv::Ext.fs_fdatasync(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, callback(:on_datasync))

            self
        end

        def truncate(offset, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(Integer, offset, "offset must be an Integer")

            @truncate_block = block
            check_result! ::Libuv::Ext.fs_ftruncate(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, offset, callback(:on_truncate))

            self
        end

        def utime(atime, mtime, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")

            @utime_block = block
            check_result! ::Libuv::Ext.fs_futime(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, atime, mtime, callback(:on_utime))

            self
        end

        def chmod(mode, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(Integer, mode, "mode must be an Integer")

            @chmod_block = block
            check_result! ::Libuv::Ext.fs_fchmod(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, mode, callback(:on_chmod))

            self
        end

        def chown(uid, gid, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")

            @chown_block = block
            check_result! ::Libuv::Ext.fs_fchown(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), @fd, uid, gid, callback(:on_chown))

            self
        end


        private


        def on_close(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @close_block.call(e) if @close_block
        end

        def on_read(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            unless e
                data = @read_buffer.read_string(@read_buffer_length)
            end
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @read_buffer = nil
            @read_buffer_length = nil
            @read_block.call(e, data)
        end

        def on_write(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @write_buffer = nil
            @write_buffer_length = nil
            @write_block.call(e) if @write_block
        end

        def on_stat(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            unless e
                uv_stat    = ::Libuv::Ext.fs_req_stat(req)
                uv_members = uv_stat.members

                values = Stat.members.map { |k| uv_members.include?(k) ? uv_stat[k] : nil }
                stat = Stat.new(*values)
            end
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @stat_block.call(e, stat)
        end

        def on_sync(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @sync_block.call(e)
        end

        def on_datasync(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @datasync_block.call(e)
        end

        def on_truncate(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @truncate_block.call(e)
        end

        def on_utime(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @utime_block.call(e)
        end

        def on_chmod(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @chmod_block.call(e)
        end

        def on_chown(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
            @chown_block.call(e)
        end
    end
end