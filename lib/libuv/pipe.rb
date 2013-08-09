module Libuv
    class Pipe
        include Stream


        def open(fileno)
            assert_type(Integer, fileno, "io#fileno must return an integer file descriptor")

            check_result! ::Libuv::Ext.pipe_open(handle, fileno)

            self
        end

        def bind(name)
            assert_type(String, name, "name must be a String")

            name = windows_path name if FFI::Platform.windows?
            check_result! ::Libuv::Ext.pipe_bind(handle, name)

            self
        end

        def connect(name)
            begin
                @deferred = @loop.defer
                assert_type(String, name, "name must be a String")
                name = windows_path name if FFI::Platform.windows?
                ::Libuv::Ext.pipe_connect(::Libuv::Ext.create_request(:uv_connect), handle, name, callback(:on_connect))
            rescue Exception => e
                @deferred.reject(e)
            ensure
                @deferred.promise
            end
        end

        def pending_instances=(count)
            assert_type(Integer, count, "count must be an Integer")

            ::Libuv::Ext.pipe_pending_instances(handle, count)

            self
        end


        private


        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            resolve @deferred, status
        end

        def windows_path(name)
            # test for \\\\.\\pipe
            if not name =~ /(\/|\\){2}\.(\/|\\)pipe/i
                name = ::File.join("\\\\.\\pipe", name)
            end
            name.gsub("/", "\\")
        end
    end
end
