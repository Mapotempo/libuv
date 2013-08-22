module Libuv
    class Pipe < Handle
        include Stream


        def initialize(loop, ipc, acceptor = nil)
            @loop, @ipc = loop, ipc

            pipe_ptr = ::Libuv::Ext.create_handle(:uv_pipe)
            error = check_result(::Libuv::Ext.pipe_init(loop.handle, pipe_ptr, ipc ? 1 : 0))
            error = check_result(::Libuv::Ext.accept(acceptor, pipe_ptr)) if acceptor && error.nil?
            
            super(pipe_ptr, error)
        end

        def bind(name, callback = nil, &blk)
            @on_listen = callback || blk
            assert_type(String, name, "name must be a String")
            name = windows_path name if FFI::Platform.windows?

            error = check_result ::Libuv::Ext.pipe_bind(handle, name)
            reject(error) if error
        end

        def accept(callback = nil, &blk)
            pipe = nil
            begin
                pipe = Pipe.new(loop, @ipc, handle)
            rescue Exception => e
                @loop.log :info, :pipe_accept_failed, e
            end
            if pipe
                begin
                    (callback || blk).call(pipe)
                rescue Exception => e
                    @loop.log :error, :pipe_accept_cb, e
                end
            end
            nil
        end

        def open(fileno, callback = nil, &blk)
            @callback = callback || blk
            assert_type(Integer, fileno, "io#fileno must return an integer file descriptor")
            begin
                check_result! ::Libuv::Ext.pipe_open(handle, fileno)

                # Emulate on_connect behavior
                begin
                    @callback.call(self)
                rescue Exception => e
                    @loop.log :error, :pipe_connect_cb, e
                end
            rescue Exception => e
                reject(e)
            end
        end

        def connect(name, callback = nil, &blk)
            @callback = callback || blk
            assert_type(String, name, "name must be a String")
            begin
                name = windows_path name if FFI::Platform.windows?
                ::Libuv::Ext.pipe_connect(::Libuv::Ext.create_request(:uv_connect), handle, name, callback(:on_connect))
            rescue Exception => e
                reject(e)
            end
        end

        # Windows only
        def pending_instances=(count)
            assert_type(Integer, count, "count must be an Integer")
            ::Libuv::Ext.pipe_pending_instances(handle, count)
        end


        private


        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            begin
                @callback.call(self)
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
    end
end
