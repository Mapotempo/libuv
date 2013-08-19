module Libuv
    class Timer
        include Assertions, Handle


        def initialize(loop)
            timer_ptr = ::Libuv::Ext.create_handle(:uv_timer)
            super(loop, timer_ptr)
            result = check_result(::Libuv::Ext.timer_init(loop.handle, timer_ptr))
            @handle_deferred.reject(result) if result
        end

        def start(timeout, repeat = 0)
            begin
                assert_type(Integer, timeout, "timeout must be an Integer")
                assert_type(Integer, repeat, "repeat must be an Integer")

                check_result! ::Libuv::Ext.timer_start(handle, callback(:on_timer), timeout, repeat)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def stop
            begin
                check_result! ::Libuv::Ext.timer_stop(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def again
            begin
                check_result! ::Libuv::Ext.timer_again(handle)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def repeat=(repeat)
            begin
                assert_type(Integer, repeat, "repeat must be an Integer")

                check_result! ::Libuv::Ext.timer_set_repeat(handle, repeat)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def repeat
            ::Libuv::Ext.timer_get_repeat(handle)
        end


        private


        def on_timer(handle, status)
            e = check_result(status)

            if e
                @handle_deferred.reject(e)
            else
                @handle_deferred.notify(self)   # notify of a new connection
            end
        end
    end
end
