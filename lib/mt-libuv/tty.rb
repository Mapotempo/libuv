# frozen_string_literal: true

module MTLibuv
    class TTY < Handle
        include Stream


        def initialize(reactor, fileno, readable)
            @reactor = reactor

            tty_ptr = ::MTLibuv::Ext.allocate_handle_tty
            error = check_result(::MTLibuv::Ext.tty_init(reactor.handle, tty_ptr, fileno, readable ? 1 : 0))
            
            super(tty_ptr, error)
        end

        def enable_raw_mode
            return if @closed
            check_result ::MTLibuv::Ext.tty_set_mode(handle, 1)
            self
        end

        def disable_raw_mode
            return if @closed
            check_result ::MTLibuv::Ext.tty_set_mode(handle, 0)
            self
        end

        def reset_mode
            ::MTLibuv::Ext.tty_reset_mode
            self
        end

        def winsize
            return [] if @closed
            width = FFI::MemoryPointer.new(:int)
            height = FFI::MemoryPointer.new(:int)
            ::MTLibuv::Ext.tty_get_winsize(handle, width, height)
            [width.get_int(0), height.get_int(0)]
        end
    end
end
