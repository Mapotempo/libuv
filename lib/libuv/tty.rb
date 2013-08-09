module Libuv
    class TTY
        include Stream


        def enable_raw_mode
            check_result! ::Libuv::Ext.tty_set_mode(handle, 1)
            self
        end

        def disable_raw_mode
            check_result! ::Libuv::Ext.tty_set_mode(handle, 0)
            self
        end

        def reset_mode
            ::Libuv::Ext.tty_reset_mode
            self
        end

        def winsize
            width = FFI::MemoryPointer.new(:int)
            height = FFI::MemoryPointer.new(:int)
            ::Libuv::Ext.tty_get_winsize(handle, width, height)
            [width.get_int(0), height.get_int(0)]
        end
    end
end
