module Libuv
    class SimpleAsync < Async


        def initialize(loop, callback = nil, &blk)
            @callback = callback || blk
            super(loop)
        end


        private


        def on_async(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :simple_async_cb, e
                end
            end
        end
    end
end
