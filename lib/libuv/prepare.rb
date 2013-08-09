module Libuv
    class Prepare
        include Handle


        def start
            begin
                @deferred = @loop.defer
                check_result! ::Libuv::Ext.prepare_start(handle, callback(:on_prepare))
            rescue Exception => e
                @deferred.reject(e)
            ensure
                @deferred.promise
            end
        end

        def stop
            check_result! ::Libuv::Ext.prepare_stop(handle)
            self
        end


        private


        def on_prepare(handle, status)
            resolve @deferred, status
        end
    end
end
