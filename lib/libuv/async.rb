module Libuv
    class Async
        include Handle


        def initialize(loop, async_ptr, &block)
            @async_block = block
            super(loop, async_ptr)
        end

        def call
            check_result! ::Libuv::Ext.async_send(handle)
            self
        end


        private


        def on_async(handle, status)
            begin
                @async_block.call(check_result(status))
            rescue Exception => e
                # TODO:: log errors, don't want to crash the loop thread
            end
        end

        public :callback
    end
end