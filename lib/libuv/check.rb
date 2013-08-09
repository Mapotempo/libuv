module Libuv
    class Check
        include Handle


        def start
            begin
                @check_deferred = @loop.defer
                check_result! ::Libuv::Ext.check_start(handle, callback(:on_check))
            rescue Exception => e
                @check_deferred.reject(e)
            ensure
                @check_deferred.promise
            end
        end

        def stop
            check_result! ::Libuv::Ext.check_stop(handle)
            self
        end


        private


        def on_check(handle, status)
            resolve @check_deferred, status
        end
    end
end