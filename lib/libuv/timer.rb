module Libuv
    class Timer < Handle
        include Assertions


        TIMEOUT_ERROR = "timeout must be an Integer".freeze
        REPEAT_ERROR = "repeat must be an Integer".freeze


        def initialize(loop)
            timer_ptr = ::Libuv::Ext.create_handle(:uv_timer)
            result = check_result(::Libuv::Ext.timer_init(loop.handle, timer_ptr))

            if result.nil?
                super(loop, timer_ptr, self, false)
            else
                super(loop, timer_ptr, result, true)
            end
        end

        def start(timeout, repeat = 0, callback = nil, &blk)
            @callback = callback || blk

            assert_block(@callback)
            assert_type(Integer, timeout, TIMEOUT_ERROR)
            assert_type(Integer, repeat, REPEAT_ERROR)

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
            assert_type(Integer, repeat, REPEAT_ERROR)

            check_result! ::Libuv::Ext.timer_set_repeat(handle, repeat)
            self
        end

        def repeat
            ::Libuv::Ext.timer_get_repeat(handle)
        end


        private


        def on_timer(handle, status)
            e = check_result(status)

            if e
                @loop.log :error, :timer_cb, e
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :timer_cb, e
                end
            end
        end
    end
end
