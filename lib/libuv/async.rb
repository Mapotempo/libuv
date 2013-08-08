module Libuv
    class Async
        include Handle


        def initialize(loop, async_ptr, &block)
            @async_block = block
            super(loop, async_ptr)
        end

        def call
            check_result ::Libuv::Ext.async_send(handle)
            self
        end


        private


        def on_async(handle, status)
            @async_block.call(check_result(status))
        end

        public :callback
    end
end