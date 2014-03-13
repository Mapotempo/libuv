module Libuv
    class Pipe < Handle
        include Stream


        WRITE2_ERROR = "data must be a String".freeze


        def initialize(loop, ipc, acceptor = nil)
            @loop, @ipc = loop, ipc

            pipe_ptr = ::Libuv::Ext.create_handle(:uv_pipe)
            error = check_result(::Libuv::Ext.pipe_init(loop.handle, pipe_ptr, ipc ? 1 : 0))
            error = check_result(::Libuv::Ext.accept(acceptor, pipe_ptr)) if acceptor && error.nil?
            
            super(pipe_ptr, error)
        end

        def bind(name, callback = nil, &blk)
            return if @closed
            @on_listen = callback || blk
            assert_type(String, name, "name must be a String")
            name = windows_path name if FFI::Platform.windows?

            error = check_result ::Libuv::Ext.pipe_bind(handle, name)
            reject(error) if error
        end

        def accept(callback = nil, &blk)
            pipe = nil
            begin
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
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
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
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
            return if @closed
            @callback = callback || blk
            assert_type(String, name, "name must be a String")
            begin
                name = windows_path name if FFI::Platform.windows?
                ::Libuv::Ext.pipe_connect(::Libuv::Ext.create_request(:uv_connect), handle, name, callback(:on_connect))
            rescue Exception => e
                reject(e)
            end
        end

        def write2(fd, data = ".")
            deferred = @loop.defer
            if @ipc && !@closed
                begin
                    assert_type(String, data, WRITE_ERROR)
                    assert_type(Handle, fd, WRITE2_ERROR)

                    size         = data.respond_to?(:bytesize) ? data.bytesize : data.size
                    buffer       = ::Libuv::Ext.buf_init(FFI::MemoryPointer.from_string(data), size)

                    # local as this variable will be avaliable until the handle is closed
                    @write_callbacks = @write_callbacks || []

                    #
                    # create the curried callback
                    #
                    callback = FFI::Function.new(:void, [:pointer, :int]) do |req, status|
                        ::Libuv::Ext.free(req)
                        # remove the callback from the array
                        # assumes writes are done in order
                        promise = @write_callbacks.shift[0]
                        resolve promise, status
                    end


                    @write_callbacks << [deferred, callback]
                    req = ::Libuv::Ext.create_request(:uv_write)
                    error = check_result ::Libuv::Ext.write2(req, handle, buffer, 1, fd.handle, callback)

                    if error
                        @write_callbacks.pop
                        ::Libuv::Ext.free(req)
                        deferred.reject(error)

                        reject(error)       # close the handle
                    end
                rescue Exception => e
                    deferred.reject(e)  # this write exception may not be fatal
                end
            else
                deferred.reject(TypeError.new('pipe not initialized for interprocess communication'))
            end
            deferred.promise
        end

        # Windows only
        def pending_instances=(count)
            return 0 if @closed
            assert_type(Integer, count, "count must be an Integer")
            ::Libuv::Ext.pipe_pending_instances(handle, count)
        end

        def check_pending(expecting = nil)
            return nil if ::Libuv::Ext.pipe_pending_count(handle) <= 0

            pending = ::Libuv::Ext.pipe_pending_type(handle)
            raise TypeError, "IPC expecting #{expecting} and received #{pending}" if expecting && expecting != pending

            # Hide the accept logic
            remote = nil
            case pending
            when :uv_tcp
                remote = TCP.new(loop, handle)
            when :uv_pipe
                remote = Pipe.new(loop, @ipc, handle)
            else
                raise NotImplementedError, "IPC for handle #{pending} not supported"
            end
            remote
        end

        def getsockname
            size = 256
            len = FFI::MemoryPointer.new(:size_t)
            len.put_int(0, size)
            buffer = FFI::MemoryPointer.new(size)
            check_result! ::Libuv::Ext.pipe_getsockname(handle, buffer, len)
            buffer.read_string
        end


        private


        def on_connect(req, status)
            ::Libuv::Ext.free(req)
            e = check_result(status)

            if e
                reject(e)
            else
                begin
                    @callback.call(self)
                rescue Exception => e
                    @loop.log :error, :pipe_connect_cb, e
                end
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
