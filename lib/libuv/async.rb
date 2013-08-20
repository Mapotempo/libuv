module Libuv
    class Async < Handle


        def initialize(loop, callback)
            async_ptr = ::Libuv::Ext.create_handle(:uv_async)
            result = check_result(::Libuv::Ext.async_init(loop.handle, async_ptr, callback(:on_async)))

            if result.nil?
                @callback = callback
                super(loop, async_ptr, self, false)
            else
                super(loop, async_ptr, result, true)
            end
        end

        def call
            check_result! ::Libuv::Ext.async_send(handle)
            self
        end


        private


        def on_async(handle, status)
            e = check_result(status)

            if e
                @loop.log :error, :async_cb, e
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :async_cb, e
                end
            end
        end
    end
end