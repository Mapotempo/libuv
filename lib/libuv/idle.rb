module Libuv
    class Idle
        include Handle


        def initialize(loop)
            idle_ptr = ::Libuv::Ext.create_handle(:uv_idle)
            super(loop, idle_ptr)
            result = check_result(::Libuv::Ext.idle_init(loop.handle, idle_ptr))
            @handle_deferred.reject(result) if result
        end

        def start
            begin
                check_result! ::Libuv::Ext.idle_start(handle, callback(:on_idle))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def stop
            begin
                check_result! ::Libuv::Ext.idle_stop(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end


        private


        def on_idle(handle, status)
            e = check_result(status)

            if e
                @handle_deferred.reject(e)
            else
                @handle_deferred.notify(self)   # notify when idle
            end
        end
    end
end
