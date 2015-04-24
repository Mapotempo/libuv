module Libuv
    class Check < Handle


        define_callback function: :on_check


        # @param loop [::Libuv::Loop] loop this check will be associated
        # @param callback [Proc] callback to be called on loop check
        def initialize(loop, callback = nil, &blk)
            @loop = loop
            @callback = callback || blk

            check_ptr = ::Libuv::Ext.allocate_handle_check
            error = check_result(::Libuv::Ext.check_init(loop.handle, check_ptr))

            super(check_ptr, error)
        end

        # Enables the check handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.check_start(handle, callback(:on_check))
            reject(error) if error
        end

        # Disables the check handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.check_stop(handle)
            reject(error) if error
        end

        # Used to update the callback that will be triggered on loop check
        #
        # @param callback [Proc] the callback to be called on loop check
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_check(handle)
            begin
                @callback.call
            rescue Exception => e
                @loop.log :error, :check_cb, e
            end
        end
    end
end