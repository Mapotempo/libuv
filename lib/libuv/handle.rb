module Libuv
    module Handle
        include Assertions, Resource, Listener


        def initialize(loop, pointer)
            @loop, @pointer = loop, pointer
            
            @handle_deferred = @loop.defer
            @handle_promise = @handle_deferred.promise
            @handle_promise.catch do |err|  # Auto close on rejection
                self.close
                ::Libuv::Q.reject(@loop, err)
            end
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
            @handle_promise
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
            
            @handle_deferred.resolve(self)
        end
    end
end