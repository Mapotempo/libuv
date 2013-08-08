module Libuv
    class Work < Q::DeferredPromise
        include Resource, Listener


        def initialize(loop, defer, work)
            super(loop, defer)

            @work = work
            @complete = false
            @pointer = ::Libuv::Ext.create_request(:uv_work)
            @error = nil

            begin
                check_result! ::Libuv::Ext.queue_work(@loop, @pointer, callback(:on_work), callback(:on_complete))
            ensure
                ::Libuv::Ext.free(@pointer)
                @complete = true
            end
        end

        # Attempt to cancel the pending work. Returns true if the work has completed or was canceled.
        #
        # @return [true, false]
        def cancel
            if not @complete
                @complete = ::Libuv::Ext.cancel(@pointer) >= 0
            end
            @complete
        end

        # Indicates is the work has completed yet or not.
        #
        # @return [true, false]
        def completed?
            return @complete
        end


        private


        def on_complete(req, rc)
            @complete = true
            ::Libuv::Ext.free(req)

            if status < 0
                @defer.reject(@loop.lookup_error(rc))
            elsif @error
                @defer.reject(@error)
            else
                @defer.resolve(rc)
            end
        end

        def on_work(req)
            begin
                @work.call
            rescue StandardError => e
                @error = e   # Catch non-fatal errors for promise resolution
            end
        end
    end
end