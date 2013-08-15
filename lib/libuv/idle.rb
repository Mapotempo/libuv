module Libuv
    class Idle
        include Handle


        def start(&block)
            assert_block(block)
            
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
            begin
                @idle_block.call(check_result(status))
            rescue Exception => e
                # TODO:: log errors, don't want to crash the loop thread
            end
        end
    end
end
