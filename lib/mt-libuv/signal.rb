# frozen_string_literal: true

module MTLibuv
    class Signal < Handle


        define_callback function: :on_sig, params: [:pointer, :int]


        SIGNALS = {
            :HUP => 1,
            :SIGHUP => 1,
            :INT => 2,
            :SIGINT => 2,
            :TERM => 15,
            :SIGTERM => 15,
            :BREAK => 21,
            :SIGBREAK => 21,
            :WINCH => 28,
            :SIGWINCH => 28
        }


        # @param reactor [::MTLibuv::Reactor] reactor this signal handler will be associated
        # @param callback [Proc] callback to be called when the signal is triggered
        def initialize(reactor)
            @reactor = reactor

            signal_ptr = ::MTLibuv::Ext.allocate_handle_signal
            error = check_result(::MTLibuv::Ext.signal_init(reactor.handle, signal_ptr))

            super(signal_ptr, error)
        end

        # Enables the signal handler.
        def start(signal)
            return if @closed
            signal = SIGNALS[signal] if signal.is_a? Symbol
            error = check_result ::MTLibuv::Ext.signal_start(handle, callback(:on_sig), signal)
            reject(error) if error
            self
        end

        # Disables the signal handler.
        def stop
            return if @closed
            error = check_result ::MTLibuv::Ext.signal_stop(handle)
            reject(error) if error
            self
        end


        private


        def on_sig(handle, signal)
            @reactor.exec do
                defer.notify(signal)   # notify of a call
            end
        end
    end
end
