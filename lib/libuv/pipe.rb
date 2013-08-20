module Libuv
    class Pipe < Handle
        include Stream


        def self.accept(loop, handle)
            AcceptPipe.new(loop, handle)
        end


        def initialize(loop, ipc)
            pipe_ptr = ::Libuv::Ext.create_handle(:uv_pipe)
            result = check_result(::Libuv::Ext.pipe_init(loop.handle, pipe_ptr, ipc ? 1 : 0))
            
            if result
                super(loop, pipe_ptr, result, true)
            else
                super(loop, pipe_ptr, self, false)
            end
        end

        def bind(name)
            @handle_deferred = loop.defer
            begin
                assert_type(String, name, "name must be a String")
                name = windows_path name if FFI::Platform.windows?
                check_result! ::Libuv::Ext.pipe_bind(handle, name)
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_deferred.promise
        end

        def open(fileno, callback = nil, &blk)
            @handle_deferred = loop.defer
            @handle_promise = @handle_deferred.promise
            @callback = callback || blk
            begin
                assert_type(Integer, fileno, "io#fileno must return an integer file descriptor")
                check_result! ::Libuv::Ext.pipe_open(handle, fileno)

                # Emulate on_connect behavior
                begin
                    @callback.call(self, @handle_promise)
                rescue Exception => e
                    @loop.log :error, :pipe_connect_cb, e
                end
            rescue Exception => e
                @handle_deferred.reject(e)
            end
            @handle_promise
        end

        def connect(name, callback = nil, &blk)
            @handle_deferred = loop.defer
            @handle_promise = @handle_deferred.promise
            @callback = callback || blk
            begin
                assert_type(String, name, "name must be a String")
                name = windows_path name if FFI::Platform.windows?
                ::Libuv::Ext.pipe_connect(::Libuv::Ext.create_request(:uv_connect), handle, name, callback(:on_connect))
            rescue Exception => e
                @on_conenct.reject(e)
            end
            @handle_promise
        end

        def pending_instances=(count)
            assert_type(Integer, count, "count must be an Integer")
            ::Libuv::Ext.pipe_pending_instances(handle, count)
        end


        private


        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            begin
                @callback.call(self, @handle_promise)
            rescue Exception => e
                @loop.log :error, :pipe_connect_cb, e
            end
        end

        def windows_path(name)
            # test for \\\\.\\pipe
            if not name =~ /(\/|\\){2}\.(\/|\\)pipe/i
                name = ::File.join("\\\\.\\pipe", name)
            end
            name.gsub("/", "\\")
        end


        class AcceptPipe < TCP
            private :bind
            private :open
            private :connect


            def initialize(loop, newhandle)
                @pointer = ::Libuv::Ext.create_handle(:uv_pipe)
                result = check_result(::Libuv::Ext.pipe_init(loop.handle, @pointer, 1))
                result = check_result(::Libuv::Ext.accept(newhandle, @pointer)) if result.nil?

                # init promise
                if result.nil?
                    @handle_deferred = loop.defer                   # The stream
                    @response = {:handle => self, :binding => @handle_deferred.promise}    # Passes the promise object in the response
                    @error = false
                else
                    @response = result
                    @error = true
                end
                @defer = loop.defer
                @loop = loop
            end
        end
    end
end
