
module Libuv
    module FsChecks


        def stat
            @stat_deferred = @loop.defer

            request = ::Libuv::Ext.create_request(:uv_fs)
            pre_check @stat_deferred, request, ::Libuv::Ext.fs_fstat(@loop.handle, request, @fileno, callback(:on_stat))
            @stat_deferred.promise
        end


        private


        def on_stat(req)
            if post_check(req, @stat_deferred)
                uv_stat = req[:stat]
                uv_members = uv_stat.members

                stats = {}
                uv_members.each do |key|
                    stats[key] = uv_stat[key]
                end

                cleanup(req)
                @stat_deferred.resolve(stats)
            end
            @stat_deferred = nil
        end

        def pre_check(deferrable, request, result)
            error = check_result result
            if error
                ::Libuv::Ext.free(request)
                deferrable.reject(error)
            end
        end

        def cleanup(req)
            ::Libuv::Ext.fs_req_cleanup(req)
            ::Libuv::Ext.free(req)
        end

        def post_check(req, deferrable)
            error = check_result(req[:result])
            if error
                cleanup(req)
                deferrable.reject(error)
                false
            else
                true
            end
        end
    end
end
