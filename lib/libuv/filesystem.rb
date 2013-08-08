module Libuv
    class Filesystem
        include Assertions, Resource, Listener


        def initialize(loop)
            @loop = loop
        end

        def open(path, flags = 0, mode = 0, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, flags, "flags must be an Integer")
            assert_type(Integer, mode, "mode must be an Integer")

            @open_block = block
            check_result! ::Libuv::Ext.fs_open(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, flags, mode, callback(:on_open))

            self
        end

        def unlink(path, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")

            @unlink_block = block
            check_result! ::Libuv::Ext.fs_unlink(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, callback(:on_unlink))

            self
        end

        def mkdir(path, mode = 0777, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")

            @mkdir_block = block
            check_result! ::Libuv::Ext.fs_mkdir(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, mode, callback(:on_mkdir))

            self
        end

        def rmdir(path, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")

            @rmdir_block = block
            check_result! ::Libuv::Ext.fs_rmdir(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, callback(:on_rmdir))

            self
        end

        def readdir(path, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(String, path, "path must be a String")

            @readdir_block = block
            check_result! ::Libuv::Ext.fs_readdir(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, 0, callback(:on_readdir))

            self
        end

        def stat(path, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(String, path, "path must be a String")

            @stat_block = block
            check_result! ::Libuv::Ext.fs_stat(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, callback(:on_stat))

            self
        end

        def rename(old_path, new_path, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")

            @rename_block = block
            check_result! ::Libuv::Ext.fs_rename(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), old_path, new_path, callback(:on_rename))

            self
        end

        def chmod(path, mode, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")

            @chmod_block = block
            check_result! ::Libuv::Ext.fs_chmod(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, mode, callback(:on_chmod))

            self
        end

        def utime(path, atime, mtime, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")

            @utime_block = block
            check_result! ::Libuv::Ext.fs_utime(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, atime, mtime, callback(:on_utime))

            self
        end

        def lstat(path, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(String, path, "path must be a String")

            @lstat_block = block
            check_result! ::Libuv::Ext.fs_lstat(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, callback(:on_lstat))

            self
        end

        def link(old_path, new_path, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")

            @link_block = block
            check_result! ::Libuv::Ext.fs_link(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), old_path, new_path, callback(:on_link))

            self
        end

        def symlink(old_path, new_path, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")

            @symlink_block = block
            check_result! ::Libuv::Ext.fs_symlink(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), old_path, new_path, 0, callback(:on_symlink))

            self
        end

        def readlink(path, &block)
            assert_block(block)
            assert_arity(2, block)
            assert_type(String, path, "path must be a String")

            @readlink_block = block
            check_result! ::Libuv::Ext.fs_readlink(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, callback(:on_readlink))

            self
        end

        def chown(path, uid, gid, &block)
            assert_block(block)
            assert_arity(1, block)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")

            @chown_block = block
            check_result! ::Libuv::Ext.fs_chown(loop.to_ptr, ::Libuv::Ext.create_request(:uv_fs), path, uid, gid, callback(:on_chown))

            self
        end


        private


        def on_open(req)
            fd   = ::Libuv::Ext.fs_req_result(req)
            e    = check_result(fd)
            file = File.new(loop, fd) unless e

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @open_block.call(e, file) unless @open_block.nil?
            @open_block = nil
        end

        def on_unlink(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @unlink_block.call(e) unless @unlink_block.nil?
            @unlink_block = nil
        end

        def on_mkdir(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @mkdir_block.call(e) unless @mkdir_block.nil?
            @mkdir_block = nil
        end

        def on_rmdir(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @rmdir_block.call(e) unless @rmdir_block.nil?
            @rmdir_block = nil
        end

        def on_readdir(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            unless e
              string_ptr = ::Libuv::Ext.fs_req_pointer(req)
              files = string_ptr.null? ? [] : string_ptr.read_string().split("\0")
            end

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @readdir_block.call(e, files) unless @readdir_block.nil?
            @readdir_block = nil
        end

        def on_stat(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            unless e
              stat = ::Libuv::Ext.fs_req_stat(req)
            end

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @stat_block.call(e, stat) unless @stat_block.nil?
            @stat_block = nil
        end

        def on_rename(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @rename_block.call(e) unless @rename_block.nil?
            @rename_block = nil
        end

        def on_chmod(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @chmod_block.call(e)
        end

        def on_utime(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @utime_block.call(e)
        end

        def on_lstat(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            unless e
              stat = ::Libuv::Ext.fs_req_stat(req)
            end

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @lstat_block.call(e, stat)
        end

        def on_link(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @link_block.call(e)
        end

        def on_symlink(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @symlink_block.call(e)
        end

        def on_readlink(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            unless e
              string_ptr = ::Libuv::Ext.fs_req_pointer(req)
              path = string_ptr.read_string() unless string_ptr.null?
            end

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @readlink_block.call(e, path)
        end

        def on_chown(req)
            e = check_result(::Libuv::Ext.fs_req_result(req))

            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)

            @chown_block.call(e)
        end
    end
end