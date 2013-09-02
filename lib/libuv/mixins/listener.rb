require 'thread_safe'
require 'set'

module Libuv
    module Listener


        private


        CALLBACKS = ThreadSafe::Cache.new


        def callbacks
            @callbacks ||= Set.new
        end

        def callback(name)
            const_name = "#{name}_#{object_id}".to_sym
            unless CALLBACKS[const_name]
                callbacks << const_name
                CALLBACKS[const_name] = method(name)
            end
            CALLBACKS[const_name]
        end

        def clear_callbacks
            callbacks.each do |name|
                CALLBACKS.delete(name)
            end
            callbacks.clear
        end
    end
end
