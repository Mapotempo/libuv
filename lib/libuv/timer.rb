module Libuv
    class Timer
        include Assertions, Handle


        def start(timeout, repeat, &block)
            assert_block(block)
            assert_type(Integer, timeout, "timeout must be an Integer")
            assert_type(Integer, repeat, "repeat must be an Integer")

            @timer_block = block
            check_result! ::Libuv::Ext.timer_start(handle, callback(:on_timer), timeout, repeat)

            self
        end

        def stop
            check_result! ::Libuv::Ext.timer_stop(handle)
            self
        end

        def again
            check_result! ::Libuv::Ext.timer_again(handle)
            self
        end

        def repeat=(repeat)
            assert_type(Integer, repeat, "repeat must be an Integer")

            check_result! ::Libuv::Ext.timer_set_repeat(handle, repeat)
            self
        end

        def repeat
            ::Libuv::Ext.timer_get_repeat(handle)
        end


        private


        def on_timer(handle, status)
            begin
                @timer_block.call(check_result(status))
            rescue Exception => e
                # TODO:: log errors, don't want to crash the loop thread
            end
        end
    end
end
