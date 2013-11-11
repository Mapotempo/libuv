module Libuv
    class Work < Q::DeferredPromise
        include Resource, Listener


        attr_reader :error
        attr_reader :result


        # @param loop [::Libuv::Loop] loop this work request will be associated
        # @param work [Proc] callback to be called in the thread pool
        def initialize(loop, work)
            super(loop, loop.defer)

            @work = work
            @complete = false
            @pointer = ::Libuv::Ext.create_request(:uv_work)
            @error = nil    # error in callback

            error = check_result ::Libuv::Ext.queue_work(@loop, @pointer, callback(:on_work), callback(:on_complete))
            if error
                ::Libuv::Ext.free(@pointer)
                @complete = true
                @defer.reject(error)
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


        def on_complete(req, status)
            @complete = true
            ::Libuv::Ext.free(req)

            e = check_result(status)
            if e
                @defer.reject(e)
            else
                if @error
                    @defer.reject(@error)
                else
                    @defer.resolve(@result)
                end
            end
            
            # Clean up references
            clear_callbacks
        end

        def on_work(req)
            begin
                @result = @work.call
            rescue Exception => e
                @error = e   # Catch errors for promise resolution
            end
        end
    end
end