module Libuv
    class Handle < Q::DeferredPromise
        include Assertions, Resource, Listener


        attr_accessor :storage  # A place for general storage
        attr_reader :closed
        attr_reader :reactor


        define_callback function: :on_close


        def initialize(pointer, error)
            @pointer = pointer
            @instance_id = @pointer.address

            # Initialise the promise
            super(reactor, reactor.defer)

            # clean up on init error (always raise here)
            if error
                ::Libuv::Ext.free(pointer)
                defer.reject(error)
                @closed = true
                raise error
            end
        end

        # Public: Increment internal ref counter for the handle on the reactor. Useful for
        # extending the reactor with custom watchers that need to make reactor not stop
        # 
        # Returns self
        def ref
            return self if @closed
            ::Libuv::Ext.ref(handle)
            self
        end

        # Public: Decrement internal ref counter for the handle on the reactor, useful to stop
        # reactor even when there are outstanding open handles
        # 
        # Returns self
        def unref
            return self if @closed
            ::Libuv::Ext.unref(handle)
            self
        end

        def close
            return self if @closed
            @closed = true
            ::Libuv::Ext.close(handle, callback(:on_close))
            self
        end

        def active?
            ::Libuv::Ext.is_active(handle) > 0
        end

        def closing?
            ::Libuv::Ext.is_closing(handle) > 0
        end


        protected


        def handle; @pointer; end
        def defer; @defer; end
        def instance_id; @instance_id; end


        private


        # Clean up and throw an error
        def reject(reason)
            @close_error = reason
            close
        end

        def on_close(pointer)
            ::Libuv::Ext.free(pointer)
            #clear_callbacks
            cleanup_callbacks

            if @close_error
                defer.reject(@close_error)
            else
                defer.resolve(nil)
            end

            if @coroutine
                @coroutine.reject(IOError.new('handle closed'))
                @coroutine = nil
            end
        end
    end
end