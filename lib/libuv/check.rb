module Libuv
    class Check < Handle


        define_callback function: :on_check


        # @param reactor [::Libuv::Reactor] reactor this check will be associated
        # @param callback [Proc] callback to be called on reactor check
        def initialize(reactor, callback = nil, &blk)
            @reactor = reactor
            @callback = callback || blk

            check_ptr = ::Libuv::Ext.allocate_handle_check
            error = check_result(::Libuv::Ext.check_init(reactor.handle, check_ptr))

            super(check_ptr, error)
        end

        # Enables the check handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.check_start(handle, callback(:on_check))
            reject(error) if error
            self
        end

        # Disables the check handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.check_stop(handle)
            reject(error) if error
            self
        end

        # Used to update the callback that will be triggered on reactor check
        #
        # @param callback [Proc] the callback to be called on reactor check
        def progress(callback = nil, &blk)
            @callback = callback || blk
            self
        end


        private


        def on_check(handle)
            ::Fiber.new {
                begin
                    @callback.call
                rescue Exception => e
                    @reactor.log :error, :check_cb, e
                end
            }.resume
        end
    end
end