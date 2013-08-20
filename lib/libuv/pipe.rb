module Libuv
    class Pipe
        include Stream


        def initialize(loop, fileno, readable)
            pipe_ptr = ::Libuv::Ext.create_handle(:uv_pipe)
            super(loop, pipe_ptr)
            begin
                assert_type(Integer, fileno, INVALID_FILE)
                assert_boolean(readable)
                check_result!(:::Libuv::Ext.pipe_init(loop.handle, pipe_ptr, ipc ? 1 : 0))
            rescue Exception => e
                @handle_deferred.reject(e)
            end
        end

        def open(fileno)
            begin
                assert_type(Integer, fileno, "io#fileno must return an integer file descriptor")
                check_result! ::Libuv::Ext.pipe_open(handle, fileno)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
        end

        def bind(name)
            begin
                assert_type(String, name, "name must be a String")
                name = windows_path name if FFI::Platform.windows?
                check_result! ::Libuv::Ext.pipe_bind(handle, name)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
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
            begin
                assert_type(Integer, count, "count must be an Integer")
                ::Libuv::Ext.pipe_pending_instances(handle, count)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
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
