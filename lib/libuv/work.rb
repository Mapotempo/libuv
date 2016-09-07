module Libuv
    class Work < Q::DeferredPromise
        include Resource, Listener


        attr_reader :error
        attr_reader :result


        define_callback function: :on_work
        define_callback function: :on_complete, params: [:pointer, :int]


        # @param thread [::Libuv::Reactor] thread this work request will be associated
        # @param work [Proc] callback to be called in the thread pool
        def initialize(thread, work)
            super(thread, thread.defer)

            @work = work
            @complete = false
            @pointer = ::Libuv::Ext.allocate_request_work
            @error = nil    # error in callback

            @instance_id = @pointer.address

            error = check_result ::Libuv::Ext.queue_work(@reactor, @pointer, callback(:on_work), callback(:on_complete))
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

            ::Fiber.new {
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
            }.resume
            
            # Clean up references
            cleanup_callbacks @instance_id
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