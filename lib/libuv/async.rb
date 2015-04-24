module Libuv
    class Async < Handle


        define_callback function: :on_async


        # @param thread [::Libuv::Loop] loop this async callback will be associated
        def initialize(thread, callback = nil, &blk)
            @loop = thread
            @callback = callback || blk

            async_ptr = ::Libuv::Ext.allocate_handle_async
            on_async = callback(:on_async, async_ptr.address)
            error = check_result(::Libuv::Ext.async_init(loop.handle, async_ptr, on_async))

            super(async_ptr, error)
        end

        # Triggers a notify event, calling everything in the notify chain
        def call
            return if @closed
            error = check_result ::Libuv::Ext.async_send(handle)
            reject(error) if error
        end

        # Used to update the callback that will be triggered when async is called
        #
        # @param callback [Proc] the callback to be called on loop prepare
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_async(handle)
            begin
                @callback.call
            rescue Exception => e
                @loop.log :error, :async_cb, e
            end
        end
    end
end
