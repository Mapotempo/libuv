module Libuv
    module Resource


        def resolve(deferred, rc)
            if rc && rc < 0
                deferred.reject(@loop.lookup_error(rc))
            else
                deferred.resolve(nil)
            end
        end

        def check_result!(rc)
            e = @loop.lookup_error(rc) unless rc.nil? || rc >= 0
            raise e if e
        end

        def check_result(rc)
            @loop.lookup_error(rc) unless rc.nil? || rc >= 0
        end

        def to_ptr
            @pointer
        end


    end
end