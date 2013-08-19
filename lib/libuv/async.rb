module Libuv
    class Async
        include Handle


        def initialize(loop, callback)
            async_ptr = ::Libuv::Ext.create_handle(:uv_async)
            super(loop, async_ptr)
            @handle_promise.progress(callback)
            result = check_result(::Libuv::Ext.async_init(loop.handle, async_ptr, async.callback(:on_async)))
            @handle_deferred.reject(result) if result
        end

        def call
            begin
                check_result! ::Libuv::Ext.async_send(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            self
        end


        private


        def on_async(handle, status)
            e = check_result(status)

            if e
                @handle_deferred.reject(e)
            else
                @handle_deferred.notify(self)   # notify of a new connection
            end
        end
    end
end