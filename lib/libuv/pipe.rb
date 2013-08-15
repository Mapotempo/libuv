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
            @on_conenct = @loop.defer
            begin
                assert_type(String, name, "name must be a String")
                name = windows_path name if FFI::Platform.windows?
                ::Libuv::Ext.pipe_connect(::Libuv::Ext.create_request(:uv_connect), handle, name, callback(:on_connect))
            rescue Exception => e
                @on_conenct.reject(e)
            end
            @on_conenct.promise
        end

        def pending_instances=(count)
            assert_type(Integer, count, "count must be an Integer")

            ::Libuv::Ext.pipe_pending_instances(handle, count)

            self
        end


        private


        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            resolve @on_conenct, status
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
