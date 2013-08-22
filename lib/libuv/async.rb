module Libuv
    class Async < Handle


        def initialize(loop)
            @loop = loop
            async_ptr = ::Libuv::Ext.create_handle(:uv_async)
            error = check_result(::Libuv::Ext.async_init(loop.handle, async_ptr, callback(:on_async)))

            super(async_ptr, error)
        end

        def call
            return if @closed
            error = check_result ::Libuv::Ext.async_send(handle)
            reject(error) if error
        end


        private


        def on_async(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                defer.notify(self)   # notify of a call
            end
        end
    end
end
