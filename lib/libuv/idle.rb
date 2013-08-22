module Libuv
    class Idle < Handle


        def initialize(loop, callback = nil, &blk)
            @loop = loop
            @callback = callback || blk

            idle_ptr = ::Libuv::Ext.create_handle(:uv_idle)
            error = check_result(::Libuv::Ext.idle_init(loop.handle, idle_ptr))

            super(idle_ptr, error)
        end

        def start
            return if @closed
            error = check_result ::Libuv::Ext.idle_start(handle, callback(:on_idle))
            reject(error) if error
        end

        def stop
            return if @closed
            error = check_result ::Libuv::Ext.idle_stop(handle)
            reject(error) if error
        end

        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_idle(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :idle_cb, e
                end
            end
        end
    end
end
