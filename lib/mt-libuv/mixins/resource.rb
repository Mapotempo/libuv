# frozen_string_literal: true

module MTLibuv
    module Resource


        def resolve(deferred, rc)
            if rc && rc < 0
                deferred.reject(@reactor.lookup_error(rc))
            else
                deferred.resolve(nil)
            end
        end

        def check_result!(rc)
            e = @reactor.lookup_error(rc) unless rc.nil? || rc >= 0
            raise e if e
        end

        def check_result(rc)
            @reactor.lookup_error(rc) unless rc.nil? || rc >= 0
        end

        def to_ptr
            @pointer
        end


    end
end