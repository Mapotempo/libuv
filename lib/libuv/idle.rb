module Libuv
    class Idle
        include Handle


        def start(&block)
            @idle_block = block
            check_result! ::Libuv::Ext.idle_start(handle, callback(:on_idle))
            self
        end

        def stop
            check_result! ::Libuv::Ext.idle_stop(handle)
            self
        end


        private


        def on_idle(handle, status)
            @idle_block.call(check_result(status))
        end
    end
end
