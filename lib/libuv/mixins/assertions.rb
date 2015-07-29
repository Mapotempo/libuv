module Libuv
    module Assertions
        MSG_NO_PROC = 'no block given'.freeze

        def assert_block(proc, msg = MSG_NO_PROC)
            raise ArgumentError, msg, caller unless proc.respond_to? :call
        end

        def assert_type(type, actual, msg = nil)
            if not actual.kind_of?(type)
                msg ||= "value #{actual.inspect} is not a valid #{type}"
                raise ArgumentError, msg, caller
            end
        end

        def assert_boolean(actual, msg = nil)
            if not (actual.kind_of?(TrueClass) || actual.kind_of?(FalseClass))
                msg ||= "value #{actual.inspect} is not a valid Boolean"
                raise ArgumentError, msg, caller
            end
        end
    end
end
