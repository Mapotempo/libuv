# frozen_string_literal: true

module MTLibuv
    class Filesystem
        include Assertions, Resource, Listener, FsChecks


        fs_params = {
            params: [Ext::FsRequest.by_ref],
            lookup: :fs_lookup
        }
        define_callback function: :on_unlink, **fs_params
        define_callback function: :on_mkdir, **fs_params
        define_callback function: :on_rmdir, **fs_params
        define_callback function: :on_readdir, **fs_params
        define_callback function: :on_rename, **fs_params
        define_callback function: :on_chmod, **fs_params
        define_callback function: :on_utime, **fs_params
        define_callback function: :on_stat, **fs_params
        define_callback function: :on_link, **fs_params
        define_callback function: :on_symlink, **fs_params
        define_callback function: :on_readlink, **fs_params
        define_callback function: :on_chown, **fs_params


        def initialize(reactor)
            @reactor = reactor
        end

        def unlink(path, wait: true)
            assert_type(String, path, "path must be a String")
            @unlink_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @unlink_deferred, request, ::MTLibuv::Ext.fs_unlink(@reactor, request, path, callback(:on_unlink, request.address))
            respond wait, @unlink_deferred.promise
        end

        def mkdir(path, mode = 0777, wait: true)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")
            @mkdir_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @mkdir_deferred, request, ::MTLibuv::Ext.fs_mkdir(@reactor, request, path, mode, callback(:on_mkdir, request.address))
            respond wait, @mkdir_deferred.promise
        end

        def rmdir(path, wait: true)
            assert_type(String, path, "path must be a String")
            @rmdir_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @rmdir_deferred, request, ::MTLibuv::Ext.fs_rmdir(@reactor, request, path, callback(:on_rmdir, request.address))
            respond wait, @rmdir_deferred.promise
        end

        def readdir(path, wait: true)
            assert_type(String, path, "path must be a String")
            @readdir_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @readdir_deferred, request, ::MTLibuv::Ext.fs_readdir(@reactor, request, path, 0, callback(:on_readdir, request.address))
            respond wait, @readdir_deferred.promise
        end

        def rename(old_path, new_path, wait: true)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @rename_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @rename_deferred, request, ::MTLibuv::Ext.fs_rename(@reactor, request, old_path, new_path, callback(:on_rename, request.address))
            respond wait, @rename_deferred.promise
        end

        def chmod(path, mode, wait: true)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, mode, "mode must be an Integer")
            @chmod_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @chmod_deferred, request, ::MTLibuv::Ext.fs_chmod(@reactor, request, path, mode, callback(:on_chmod, request.address))
            respond wait, @chmod_deferred.promise
        end

        def utime(path, atime, mtime, wait: true)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")
            @utime_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @utime_deferred, request, ::MTLibuv::Ext.fs_utime(@reactor, request, path, atime, mtime, callback(:on_utime, request.address))
            respond wait, @utime_deferred.promise
        end

        def lstat(path, wait: true)
            assert_type(String, path, "path must be a String")
            @stat_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @stat_deferred, request, ::MTLibuv::Ext.fs_lstat(@reactor, request, path, callback(:on_stat, request.address))
            respond wait, @stat_deferred.promise
        end

        def link(old_path, new_path, wait: true)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @link_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @link_deferred, request, ::MTLibuv::Ext.fs_link(@reactor, request, old_path, new_path, callback(:on_link, request.address))
            respond wait, @link_deferred.promise
        end

        def symlink(old_path, new_path, wait: true)
            assert_type(String, old_path, "old_path must be a String")
            assert_type(String, new_path, "new_path must be a String")
            @symlink_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @symlink_deferred, request, ::MTLibuv::Ext.fs_symlink(@reactor, request, old_path, new_path, 0, callback(:on_symlink, request.address))
            respond wait, @symlink_deferred.promise
        end

        def readlink(path, wait: true)
            assert_type(String, path, "path must be a String")
            @readlink_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @readlink_deferred, request, ::MTLibuv::Ext.fs_readlink(@reactor, request, path, callback(:on_readlink, request.address))
            respond wait, @readlink_deferred.promise
        end

        def chown(path, uid, gid, wait: true)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")
            @chown_deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @chown_deferred, request, ::MTLibuv::Ext.fs_chown(@reactor, request, path, uid, gid, callback(:on_chown, request.address))
            respond wait, @chown_deferred.promise
        end


        private


        def on_unlink(req)
            if post_check(req, @unlink_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @unlink_deferred.resolve(path) }
            end
            @unlink_deferred = nil
        end

        def on_mkdir(req)
            if post_check(req, @mkdir_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @mkdir_deferred.resolve(path) }
            end
            @mkdir_deferred = nil
        end

        def on_rmdir(req)
            if post_check(req, @rmdir_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @rmdir_deferred.resolve(path) }
            end
            @rmdir_deferred = nil
        end

        def on_readdir(req)
            if post_check(req, @readdir_deferred)
                num_files = req[:result]

                info = ::MTLibuv::Ext::UvDirent.new
                files = []
                ret = 1
                loop do
                    ret = ::MTLibuv::Ext.fs_readdir_next(req, info)
                    files << [info[:name], info[:type]]

                    # EOF is the alternative
                    break unless ret == 0
                end

                cleanup(req)
                @reactor.exec { @readdir_deferred.resolve(files) }
            end
            @readdir_deferred = nil
        end

        def on_rename(req)
            if post_check(req, @rename_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @rename_deferred.resolve(path) }
            end
            @rename_deferred = nil
        end

        def on_chmod(req)
            if post_check(req, @chmod_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @chmod_deferred.resolve(path) }
            end
            @chmod_deferred = nil
        end

        def on_utime(req)
            if post_check(req, @utime_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @utime_deferred.resolve(path) }
            end
            @utime_deferred = nil
        end

        def on_link(req)
            if post_check(req, @link_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @link_deferred.resolve(path) }
            end
            @link_deferred = nil
        end

        def on_symlink(req)
            if post_check(req, @symlink_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @symlink_deferred.resolve(path) }
            end
            @symlink_deferred = nil
        end

        def on_readlink(req)
            if post_check(req, @readlink_deferred)
                string_ptr = req[:ptr]
                path = string_ptr.null? ? nil : string_ptr.read_string_to_null
                cleanup(req)
                @reactor.exec { @readlink_deferred.resolve(path) }
            end
            @readlink_deferred = nil
        end

        def on_chown(req)
            if post_check(req, @chown_deferred)
                path = req[:path]
                cleanup(req)
                @reactor.exec { @chown_deferred.resolve(path) }
            end
            @chown_deferred = nil
        end
    end
end