module Libuv
    class Handle < Q::ResolvedPromise
        include Assertions, Resource, Listener


        def initialize(loop, pointer, result, error)
            @pointer = pointer

            # Initialise the promise
            super(loop, result, error)
        end

        # Public: Increment internal ref counter for the handle on the loop. Useful for
        # extending the loop with custom watchers that need to make loop not stop
        # 
        # Returns self
        def ref
            ::Libuv::Ext.ref(@pointer)
            self
        end

        # Public: Decrement internal ref counter for the handle on the loop, useful to stop
        # loop even when there are outstanding open handles
        # 
        # Returns self
        def unref
            ::Libuv::Ext.unref(@pointer)
            self
        end

        def close(callback = nil, &blk)
            @handle_close_cb = callback || blk
            Libuv::Ext.close(@pointer, callback(:on_close))
            self
        end

        def active?
            ::Libuv::Ext.is_active(@pointer) > 0
        end

        def closing?
            ::Libuv::Ext.is_closing(@pointer) > 0
        end


        protected


        def loop; @loop; end
        def handle; @pointer; end


        private


        def handle_name
            # Seems a little hacky
            self.class.name.split('::').last.downcase.to_sym
        end

        def on_close(pointer)
            ::Libuv::Ext.free(pointer)
            clear_callbacks

            if @handle_close_cb
                begin
                    @handle_close_cb.call
                rescue Exception => e
                    @loop.log :error, :async_cb, e
                end
            end
        end
    end
end