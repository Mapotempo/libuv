module Libuv
    class Timer < Handle
        include Assertions


        TIMEOUT_ERROR = "timeout must be an Integer".freeze
        REPEAT_ERROR = "repeat must be an Integer".freeze


        def initialize(loop, callback = nil)
            @callback = callback
            timer_ptr = ::Libuv::Ext.create_handle(:uv_timer)
            error = check_result(::Libuv::Ext.timer_init(loop.handle, timer_ptr))

            super(loop, timer_ptr, error)
        end

        def start(timeout, repeat = 0)
            return if @closed
            
            assert_type(Integer, timeout, TIMEOUT_ERROR)
            assert_type(Integer, repeat, REPEAT_ERROR)

            error = check_result ::Libuv::Ext.timer_start(handle, callback(:on_timer), timeout, repeat)
            reject(error) if error
        end

        def stop
            return if @closed
            error = check_result ::Libuv::Ext.timer_stop(handle)
            reject(error) if error
        end

        def again
            return if @closed
            error = check_result ::Libuv::Ext.timer_again(handle)
            reject(error) if error
        end

        def repeat=(repeat)
            return if @closed
            assert_type(Integer, repeat, REPEAT_ERROR)
            check_result ::Libuv::Ext.timer_set_repeat(handle, repeat)
            reject(error) if error
        end

        def repeat
            return if @closed
            ::Libuv::Ext.timer_get_repeat(handle)
        end

        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_timer(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                #defer.notify(self)   # notify of a new connection
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :timer_cb, e
                end
            end
        end
    end
end
