module Libuv
    class Check
        include Handle


        def initialize(loop)
            check_ptr = ::Libuv::Ext.create_handle(:uv_check)
            super(loop, check_ptr)
            result = check_result(::Libuv::Ext.check_init(loop.handle, check_ptr))
            @handle_deferred.reject(result) if result
        end

        def start
            begin
                check_result! ::Libuv::Ext.check_start(handle, callback(:on_check))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def stop
            begin
                check_result! ::Libuv::Ext.check_stop(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end


        private


        def on_check(handle, status)
            e = check_result(status)

            if e
                @handle_deferred.reject(e)
            else
                @handle_deferred.notify(self)   # notify when idle
            end
        end
    end
end