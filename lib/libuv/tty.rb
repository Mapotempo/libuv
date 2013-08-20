module Libuv
    class TTY
        include Stream


        INVALID_FILE = "io#fileno must return an integer file descriptor, #{fileno.inspect} given".freeze


        def initialize(loop, fileno, readable)
            tty_ptr = ::Libuv::Ext.create_handle(:uv_tty)
            super(loop, tty_ptr)
            begin
                assert_boolean(ipc)
                check_result!(::Libuv::Ext.tty_init(loop.handle, tty_ptr, fileno, readable ? 1 : 0))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
        end

        def enable_raw_mode
            begin
                check_result! ::Libuv::Ext.tty_set_mode(handle, 1)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def disable_raw_mode
            begin
                check_result! ::Libuv::Ext.tty_set_mode(handle, 0)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
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
