module Libuv
    class Prepare
        include Handle


        def initialize(loop)
            prepare_ptr = ::Libuv::Ext.create_handle(:uv_prepare)
            super(loop, prepare_ptr)
            result = check_result(::Libuv::Ext.prepare_init(@pointer, prepare_ptr))
            @handle_deferred.reject(result) if result
        end

        def start
            begin
                check_result! ::Libuv::Ext.prepare_start(handle, callback(:on_prepare))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def stop
            begin
                check_result! ::Libuv::Ext.prepare_stop(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end


        private


        def on_prepare(handle, status)
            e = check_result(status)

            if e
                @handle_deferred.reject(e)
            else
                @handle_deferred.notify(self)   # notify when idle
            end
        end
    end
end
