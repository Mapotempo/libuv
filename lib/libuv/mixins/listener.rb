require 'thread_safe'
require 'set'

module Libuv
    module Listener


        private


        module ClassMethods
            def dispatch_callback(func_name, lookup, args)
                instance_id = __send__(lookup, *args)
                inst = @callback_lookup[instance_id]
                inst.__send__(func_name, *args)
            end

            def define_callback(function:, params: [:pointer], ret_val: :void, lookup: :default_lookup)
                @callback_funcs[function] = FFI::Function.new(ret_val, params) do |*args|
                    dispatch_callback(function, lookup, args)
                end
            end

            # Much like include to support inheritance properly
            # We keep existing callbacks and inherit the lookup (as this will never clash)
            def inherited(subclass)
                subclass.instance_variable_set(:@callback_funcs, {}.merge(@callback_funcs))
                subclass.instance_variable_set(:@callback_lookup, @callback_lookup)
            end


            # Provide accessor methods to the class level instance variables
            attr_reader :callback_lookup, :callback_funcs


            # This function is used to work out the instance the callback is for
            def default_lookup(req, *args)
                req.address
            end
        end

        def self.included(base)
            base.instance_variable_set(:@callback_funcs, {})
            base.instance_variable_set(:@callback_lookup, ThreadSafe::Cache.new)
            base.extend(ClassMethods)
        end



        def callback(name, instance_id = @instance_id)
            klass = self.class
            klass.callback_lookup[instance_id] ||= self
            klass.callback_funcs[name]
        end

        def cleanup_callbacks(instance_id = @instance_id)
            self.class.callback_lookup.delete(instance_id)
        end
    end
end
