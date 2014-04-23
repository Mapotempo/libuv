module Libuv
    class Idle < Handle


        # @param loop [::Libuv::Loop] loop this idle handler will be associated
        # @param callback [Proc] callback to be called when the loop is idle
        def initialize(loop, callback = nil, &blk)
            @loop = loop
            @callback = callback || blk

            idle_ptr = ::Libuv::Ext.create_handle(:uv_idle)
            error = check_result(::Libuv::Ext.idle_init(loop.handle, idle_ptr))

            super(idle_ptr, error)
        end

        # Enables the idle handler.
        def start
            return if @closed
            error = check_result ::Libuv::Ext.idle_start(handle, callback(:on_idle))
            reject(error) if error
        end

        # Disables the idle handler.
        def stop
            return if @closed
            error = check_result ::Libuv::Ext.idle_stop(handle)
            reject(error) if error
        end

        # Used to update the callback that will be triggered on idle
        #
        # @param callback [Proc] the callback to be called on idle trigger
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_idle(handle)
            begin
                @callback.call
            rescue Exception => e
                @loop.log :error, :idle_cb, e
            end
        end
    end
end
