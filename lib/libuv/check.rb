module Libuv
    class Check < Handle


        def initialize(loop, callback = nil, &blk)
            @loop = loop
            @callback = callback || blk

            check_ptr = ::Libuv::Ext.create_handle(:uv_check)
            error = check_result(::Libuv::Ext.check_init(loop.handle, check_ptr))

            super(check_ptr, error)
        end

        def start
            return if @closed
            error = check_result ::Libuv::Ext.check_start(handle, callback(:on_check))
            reject(error) if error
        end

        def stop
            return if @closed
            error = check_result ::Libuv::Ext.check_stop(handle)
            reject(error) if error
        end

        def progress(callback = nil, &blk)
            @callback = callback || blk
        end


        private


        def on_check(handle, status)
            e = check_result(status)

            if e
                reject(e)
            else
                begin
                    @callback.call
                rescue Exception => e
                    @loop.log :error, :check_cb, e
                end
            end
        end
    end
end