# frozen_string_literal: true

module MTLibuv
    class Async < Handle


        define_callback function: :on_async


        # @param reactor [::MTLibuv::Reactor] reactor this async callback will be associated
        def initialize(reactor)
            @reactor = reactor

            async_ptr = ::MTLibuv::Ext.allocate_handle_async
            on_async = callback(:on_async, async_ptr.address)
            error = check_result(::MTLibuv::Ext.async_init(reactor.handle, async_ptr, on_async))

            super(async_ptr, error)
        end

        # Triggers a notify event, calling everything in the notify chain
        def call
            return if @closed
            error = check_result ::MTLibuv::Ext.async_send(handle)
            reject(error) if error
            self
        end

        # Used to update the callback that will be triggered when async is called
        #
        # @param callback [Proc] the callback to be called on reactor prepare
        def progress(&callback)
            @callback = callback
            self
        end


        private


        def on_async(handle)
            @reactor.exec do
                begin
                    @callback.call
                rescue Exception => e
                    @reactor.log e, 'performing async callback'
                end
            end
        end
    end
end
