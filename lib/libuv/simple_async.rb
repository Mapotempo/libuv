module Libuv
    class SimpleAsync < Async


        # @param loop [::Libuv::Loop] loop this simple async callback will be associated
        # @param callback [Proc] callback to be called when triggered
        def initialize(loop, callback = nil, &blk)
            @callback = callback || blk
            super(loop)
        end

        # Used to update the callback that will be triggered when async is called
        #
        # @param callback [Proc] the callback to be called on loop prepare
        def progress(callback = nil, &blk)
            @callback = callback || blk
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
