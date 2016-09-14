# frozen_string_literal: true

module Libuv
    class Idle < Handle


        define_callback function: :on_idle


        # @param reactor [::Libuv::Reactor] reactor this idle handler will be associated
        # @param callback [Proc] callback to be called when the reactor is idle
        def initialize(reactor, callback = nil, &blk)
            @reactor = reactor
            @callback = callback || blk

            idle_ptr = ::Libuv::Ext.allocate_handle_idle
            error = check_result(::Libuv::Ext.idle_init(reactor.handle, idle_ptr))

            super(idle_ptr, error)
        end

        # Enables the idle handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.idle_start(handle, callback(:on_idle))
            reject(error) if error
            self
        end

        # Disables the idle handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.idle_stop(handle)
            reject(error) if error
            self
        end

        # Used to update the callback that will be triggered on idle
        #
        # @param callback [Proc] the callback to be called on idle trigger
        def progress(callback = nil, &blk)
            @callback = callback || blk
            self
        end


        private


        def on_idle(handle)
            ::Fiber.new {
                begin
                    @callback.call
                rescue Exception => e
                    @reactor.log e, 'performing idle callback'
                end
            }.resume
        end
    end
end
