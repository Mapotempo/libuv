module Libuv
    class Prepare < Handle


        define_callback function: :on_prepare


        # @param reactor [::Libuv::Reactor] reactor this prepare handle will be associated
        # @param callback [Proc] callback to be called on reactor preparation
        def initialize(reactor, callback = nil, &blk)
            @reactor = reactor
            @callback = callback || blk

            prepare_ptr = ::Libuv::Ext.allocate_handle_prepare
            error = check_result(::Libuv::Ext.prepare_init(reactor.handle, prepare_ptr))

            super(prepare_ptr, error)
        end

        # Enables the prepare handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.prepare_start(handle, callback(:on_prepare))
            reject(error) if error
        end

        # Disables the prepare handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.prepare_stop(handle)
            reject(error) if error
        end

        # Used to update the callback that will be triggered on reactor prepare
        #
        # @param callback [Proc] the callback to be called on reactor prepare
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_prepare(handle)
            begin
                @callback.call
            rescue Exception => e
                @reactor.log :error, :prepare_cb, e
            end
        end
    end
end
