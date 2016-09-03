module Libuv
    class Timer < Handle


        define_callback function: :on_timer


        # @param reactor [::Libuv::Reactor] reactor this timer will be associated
        # @param callback [Proc] callback to be called when the timer is triggered
        def initialize(reactor, callback = nil, &blk)
            @reactor = reactor
            @callback = callback || blk
            
            timer_ptr = ::Libuv::Ext.allocate_handle_timer
            error = check_result(::Libuv::Ext.timer_init(reactor.handle, timer_ptr))
            @stopped = true

            super(timer_ptr, error)
        end

        # Enables the timer. A repeat of 0 means no repeat
        #
        # @param timeout [Integer|Fixnum] time in milliseconds before the timer callback is triggered the first time
        # @param repeat [Integer|Fixnum] time in milliseconds between repeated callbacks after the first
        def start(timeout, repeat = 0)
            return if @closed
            @stopped = false

            # prevent timeouts less than 0 (very long time otherwise as cast to an unsigned)
            # and you probably don't want to wait a few lifetimes
            timeout = timeout.to_i
            timeout = 0 if timeout < 0

            error = check_result ::Libuv::Ext.timer_start(handle, callback(:on_timer), timeout, repeat.to_i)
            reject(error) if error

            self
        end

        # Disables the timer.
        def stop
            return if @stopped || @closed
            @stopped = true
            error = check_result ::Libuv::Ext.timer_stop(handle)
            reject(error) if error

            self
        end

        # Resets the current repeat
        def again
            return if @closed
            error = check_result ::Libuv::Ext.timer_again(handle)
            reject(error) if error

            self
        end

        # Set the current repeat timeout
        # Repeat is the time in milliseconds between repeated callbacks after the initial timeout fires
        #
        # @param time [Integer|Fixnum] time in milliseconds between repeated callbacks after the first
        def repeat=(time)
            return if @closed
            error = check_result ::Libuv::Ext.timer_set_repeat(handle, time.to_i)
            reject(error) if error
            time
        end

        # Set or gets the current repeat timeout
        # Repeat is the time in milliseconds between repeated callbacks after the initial timeout fires
        #
        # @param times [Integer|Fixnum] time in milliseconds between repeated callbacks after the first
        def repeat(time = nil)
            return if @closed
            if time.nil?
                ::Libuv::Ext.timer_get_repeat(handle)
            else
                self.repeat = time
                self
            end
        end

        # Used to update the callback to be triggered by the timer
        #
        # @param callback [Proc] the callback to be called by the timer
        def progress(callback = nil, &blk)
            @callback = callback || blk

            self
        end


        private


        def on_timer(handle)
            begin
                @callback.call
            rescue Exception => e
                @reactor.log :error, :timer_cb, e
            end
        end
    end
end
