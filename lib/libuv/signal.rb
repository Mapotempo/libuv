module Libuv
    class Signal < Handle


        SIGNALS = {
            :HUP => 1,
            :SIGHUP => 1,
            :INT => 2,
            :SIGINT => 2,
            :BREAK => 21,
            :SIGBREAK => 21,
            :WINCH => 28,
            :SIGWINCH => 28
        }


        # @param loop [::Libuv::Loop] loop this signal handler will be associated
        # @param callback [Proc] callback to be called when the signal is triggered
        def initialize(loop)
            @loop = loop

            signal_ptr = ::Libuv::Ext.create_handle(:uv_signal)
            error = check_result(::Libuv::Ext.signal_init(loop.handle, signal_ptr))

            super(signal_ptr, error)
        end

        # Enables the signal handler.
        def start(signal)
            return if @closed
            signal = SIGNALS[signal] if signal.is_a? Symbol
            error = check_result ::Libuv::Ext.signal_start(handle, callback(:on_sig), signal)
            reject(error) if error
        end

        # Disables the signal handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.signal_stop(handle)
            reject(error) if error
        end


        private


        def on_sig(handle, signal)
            defer.notify(signal)   # notify of a call
        end
    end
end
