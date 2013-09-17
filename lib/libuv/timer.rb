module Libuv
    class Timer < Handle
        include Assertions


        TIMEOUT_ERROR = "timeout must be an Integer".freeze
        REPEAT_ERROR = "repeat must be an Integer".freeze


        # @param loop [::Libuv::Loop] loop this timer will be associated
        # @param callback [Proc] callback to be called when the timer is triggered
        def initialize(loop, callback = nil)
            @loop, @callback = loop, callback
            
            timer_ptr = ::Libuv::Ext.create_handle(:uv_timer)
            error = check_result(::Libuv::Ext.timer_init(loop.handle, timer_ptr))
            @stopped = true

            super(timer_ptr, error)
        end

        # Enables the timer. A repeat of 0 means no repeat
        #
        # @param timeout [Fixnum] time in milliseconds before the timer callback is triggered the first time
        # @param repeat [Fixnum] time in milliseconds between repeated callbacks after the first
        def start(timeout, repeat = 0)
            return if @closed
            @stopped = false

            assert_type(Integer, timeout, TIMEOUT_ERROR)
            assert_type(Integer, repeat, REPEAT_ERROR)

            error = check_result ::Libuv::Ext.timer_start(handle, callback(:on_timer), timeout, repeat)
            reject(error) if error
        end

        # Disables the timer.
        def stop
            return if @stopped || @closed
            @stopped = true
            error = check_result ::Libuv::Ext.timer_stop(handle)
            reject(error) if error
        end

        # Resets the current repeat
        def again
            return if @closed
            error = check_result ::Libuv::Ext.timer_again(handle)
            reject(error) if error
        end

        # Updates the repeat timeout
        def repeat=(repeat)
            return if @closed
            assert_type(Integer, repeat, REPEAT_ERROR)
            check_result ::Libuv::Ext.timer_set_repeat(handle, repeat)
            reject(error) if error
        end

        # Returns the current repeat timeout
        def repeat
            return if @closed
            ::Libuv::Ext.timer_get_repeat(handle)
        end

        # Used to update the callback to be triggered by the timer
        #
        # @param callback [Proc] the callback to be called by the timer
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_timer(handle, status)
            e = check_result(status)

            if e
                reject(e)
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
