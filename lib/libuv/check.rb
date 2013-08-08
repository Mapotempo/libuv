module Libuv
    class Check
        include Handle


        def start(&block)
            @check_block = block
            check_result! ::Libuv::Ext.check_start(handle, callback(:on_check))
            self
        end

        def stop
            check_result! ::Libuv::Ext.check_stop(handle)
            self
        end


        private


        def on_check(handle, status)
          @check_block.call(check_result(status))
        end
    end
end