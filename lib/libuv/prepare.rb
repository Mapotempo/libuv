module Libuv
    class Prepare < Handle


        # @param loop [::Libuv::Loop] loop this prepare handle will be associated
        # @param callback [Proc] callback to be called on loop preparation
        def initialize(loop, callback = nil, &blk)
            @loop = loop
            @callback = callback || blk

            prepare_ptr = ::Libuv::Ext.create_handle(:uv_prepare)
            error = check_result(::Libuv::Ext.prepare_init(loop.handle, prepare_ptr))

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

        # Used to update the callback that will be triggered on loop prepare
        #
        # @param callback [Proc] the callback to be called on loop prepare
        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_prepare(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :prepare_cb, e
                end
            end
        end
    end
end
