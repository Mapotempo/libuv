module Libuv
    class TTY < Handle
        include Stream


        def initialize(loop, fileno, readable)
            @loop = loop

            tty_ptr = ::Libuv::Ext.allocate_handle_tty
            error = check_result(::Libuv::Ext.tty_init(loop.handle, tty_ptr, fileno, readable ? 1 : 0))
            
            super(tty_ptr, error)
        end

        def enable_raw_mode
            return if @closed
            check_result ::Libuv::Ext.tty_set_mode(handle, 1)
        end

        def disable_raw_mode
            return if @closed
            check_result ::Libuv::Ext.tty_set_mode(handle, 0)
        end

        def reset_mode
            ::Libuv::Ext.tty_reset_mode
        end

        def winsize
            return [] if @closed
            width = FFI::MemoryPointer.new(:int)
            height = FFI::MemoryPointer.new(:int)
            ::Libuv::Ext.tty_get_winsize(handle, width, height)
            [width.get_int(0), height.get_int(0)]
        end
    end
end
