module Libuv
    module Handle
        include Assertions, Resource, Listener


        def initialize(loop, pointer)
            @loop, @pointer = loop, pointer
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

        def close
            Libuv::Ext.close(@pointer, callback(:on_close))
            @close_promise = @loop.defer
            @close_promise.promise
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
            self.class.name.split('::').last.downcase.to_sym
        end

        def on_close(pointer)
            ::Libuv::Ext.free(pointer)
            clear_callbacks
            
            @close_promise.resolve(true)
            @close_promise = nil
        end
    end
end