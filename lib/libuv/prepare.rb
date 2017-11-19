# frozen_string_literal: true

module Libuv
    class Prepare < Handle


        define_callback function: :on_prepare


        # @param reactor [::Libuv::Reactor] reactor this prepare handle will be associated
        # @param callback [Proc] callback to be called on reactor preparation
        def initialize(reactor)
            @reactor = reactor

            prepare_ptr = ::Libuv::Ext.allocate_handle_prepare
            error = check_result(::Libuv::Ext.prepare_init(reactor.handle, prepare_ptr))

            super(prepare_ptr, error)
        end

        # Enables the prepare handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.prepare_start(handle, callback(:on_prepare))
            reject(error) if error
            self
        end

        # Disables the prepare handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.prepare_stop(handle)
            reject(error) if error
            self
        end

        # Used to update the callback that will be triggered on reactor prepare
        #
        # @param callback [Proc] the callback to be called on reactor prepare
        def progress(&callback)
            @callback = callback
            self
        end


        private


        def on_prepare(handle)
            @reactor.exec do
                begin
                    @callback.call
                rescue Exception => e
                    @reactor.log e, 'performing prepare callback'
                end
            end
        end
    end
end
