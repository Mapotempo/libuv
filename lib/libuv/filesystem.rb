module Libuv
    class Filesystem
        include Assertions, Resource, Listener, FsChecks


        def initialize(loop)
            @loop = loop
        end

        def unlink(path)
            assert_type(String, path, "path must be a String")
            @unlink_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @unlink_deferred, request, ::Libuv::Ext.fs_unlink(@loop, request, path, callback(:on_unlink))
            @unlink_deferred.promise
        end

        def mkdir(path, mode = 0777)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")
            @mkdir_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @mkdir_deferred, request, ::Libuv::Ext.fs_mkdir(@loop, request, path, mode, callback(:on_mkdir))
            @mkdir_deferred.promise
        end

        def rmdir(path)
            assert_type(String, path, "path must be a String")
            @rmdir_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @rmdir_deferred, request, ::Libuv::Ext.fs_rmdir(@loop, request, path, callback(:on_rmdir))
            @rmdir_deferred.promise
        end

        def readdir(path)
            assert_type(String, path, "path must be a String")
            @readdir_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @readdir_deferred, request, ::Libuv::Ext.fs_readdir(@loop, request, path, 0, callback(:on_readdir))
            @readdir_deferred.promise
        end

        def rename(old_path, new_path)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @rename_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @rename_deferred, request, ::Libuv::Ext.fs_rename(@loop, request, old_path, new_path, callback(:on_rename))
            @rename_deferred.promise
        end

        def chmod(path, mode)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")
            @chmod_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @chmod_deferred, request, ::Libuv::Ext.fs_chmod(@loop, request, path, mode, callback(:on_chmod))
            @chmod_deferred.promise
        end

        def utime(path, atime, mtime)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")
            @utime_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @utime_deferred, request, ::Libuv::Ext.fs_utime(@loop, request, path, atime, mtime, callback(:on_utime))
            @utime_deferred.promise
        end

        def lstat(path)
            assert_type(String, path, "path must be a String")
            @stat_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @stat_deferred, request, ::Libuv::Ext.fs_lstat(@loop, request, path, callback(:on_stat))
            @stat_deferred.promise
        end

        def link(old_path, new_path)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @link_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @link_deferred, request, ::Libuv::Ext.fs_link(@loop, request, old_path, new_path, callback(:on_link))
            @link_deferred.promise
        end

        def symlink(old_path, new_path)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @symlink_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @symlink_deferred, request, ::Libuv::Ext.fs_symlink(@loop, request, old_path, new_path, 0, callback(:on_symlink))
            @symlink_deferred.promise
        end

        def readlink(path)
            assert_type(String, path, "path must be a String")
            @readlink_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @readlink_deferred, request, ::Libuv::Ext.fs_readlink(@loop, request, path, callback(:on_readlink))
            @readlink_deferred.promise
        end

        def chown(path, uid, gid)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")
            @chown_deferred = @loop.defer

            request = ::Libuv::Ext.allocate_request_fs
            pre_check @chown_deferred, request, ::Libuv::Ext.fs_chown(@loop, request, path, uid, gid, callback(:on_chown))
            @chown_deferred.promise
        end


        private


        def on_unlink(req)
            if post_check(req, @unlink_deferred)
                path = req[:path]
                cleanup(req)
                @unlink_deferred.resolve(path)
            end
            @unlink_deferred = nil
        end

        def on_mkdir(req)
            if post_check(req, @mkdir_deferred)
                path = req[:path]
                cleanup(req)
                @mkdir_deferred.resolve(path)
            end
            @mkdir_deferred = nil
        end

        def on_rmdir(req)
            if post_check(req, @rmdir_deferred)
                path = req[:path]
                cleanup(req)
                @rmdir_deferred.resolve(path)
            end
            @rmdir_deferred = nil
        end

        def on_readdir(req)
            if post_check(req, @readdir_deferred)
                num_files = req[:result]

                info = ::Libuv::Ext::UvDirent.new
                files = []
                ret = 1
                loop do
                    ret = ::Libuv::Ext.fs_readdir_next(req, info)
                    files << [info[:name], info[:type]]

                    # EOF is the alternative
                    break unless ret == 0
                end

                cleanup(req)
                @readdir_deferred.resolve(files)
            end
            @readdir_deferred = nil
        end

        def on_rename(req)
            if post_check(req, @rename_deferred)
                path = req[:path]
                cleanup(req)
                @rename_deferred.resolve(path)
            end
            @rename_deferred = nil
        end

        def on_chmod(req)
            if post_check(req, @chmod_deferred)
                path = req[:path]
                cleanup(req)
                @chmod_deferred.resolve(path)
            end
            @chmod_deferred = nil
        end

        def on_utime(req)
            if post_check(req, @utime_deferred)
                path = req[:path]
                cleanup(req)
                @utime_deferred.resolve(path)
            end
            @utime_deferred = nil
        end

        def on_link(req)
            if post_check(req, @link_deferred)
                path = req[:path]
                cleanup(req)
                @link_deferred.resolve(path)
            end
            @link_deferred = nil
        end

        def on_symlink(req)
            if post_check(req, @symlink_deferred)
                path = req[:path]
                cleanup(req)
                @symlink_deferred.resolve(path)
            end
            @symlink_deferred = nil
        end

        def on_readlink(req)
            if post_check(req, @readlink_deferred)
                string_ptr = req[:ptr]
                path = string_ptr.null? ? nil : string_ptr.read_string_to_null
                cleanup(req)
                @readlink_deferred.resolve(path)
            end
            @readlink_deferred = nil
        end

        def on_chown(req)
            if post_check(req, @chown_deferred)
                path = req[:path]
                cleanup(req)
                @chown_deferred.resolve(path)
            end
            @chown_deferred = nil
        end
    end
end