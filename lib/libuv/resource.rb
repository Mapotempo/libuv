module Libuv
    module Resource


        def resolve(deferred, rc)
            if rc >= 0
                deferred.resolve(rc)
            else
                deferred.reject(@loop.lookup_error(rc))
            end
        end

        def check_result!(rc)
            e = @loop.lookup_error(rc) unless rc >= 0
            raise e if e
        end

        def to_ptr
            @pointer
        end


        protected


        attr_reader :loop
    end
end