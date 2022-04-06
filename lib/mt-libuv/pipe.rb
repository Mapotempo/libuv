# frozen_string_literal: true

module MTLibuv
    class Pipe < Handle
        include Stream


        define_callback function: :on_connect, params: [:pointer, :int]
        define_callback function: :write2_complete, params: [:pointer, :int]


        WRITE2_ERROR = "data must be a String"


        def initialize(reactor, ipc, acceptor = nil)
            @reactor, @ipc = reactor, ipc

            pipe_ptr = ::MTLibuv::Ext.allocate_handle_pipe
            error = check_result(::MTLibuv::Ext.pipe_init(reactor.handle, pipe_ptr, ipc ? 1 : 0))
            error = check_result(::MTLibuv::Ext.accept(acceptor, pipe_ptr)) if acceptor && error.nil?
            
            super(pipe_ptr, error)
        end

        def bind(name, &callback)
            return if @closed
            @on_accept = callback
            @on_listen = proc { accept }

            assert_type(String, name, "name must be a String")
            name = windows_path name if FFI::Platform.windows?

            error = check_result ::MTLibuv::Ext.pipe_bind(handle, name)
            reject(error) if error

            self
        end

        def open(fileno)
            assert_type(Integer, fileno, 'fileno must be an integer file descriptor')

            begin
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
                check_result! ::MTLibuv::Ext.pipe_open(handle, fileno)

                # Emulate on_connect behavior
                if block_given?
                    begin
                        yield(self)
                    rescue Exception => e
                        @reactor.log e, 'performing pipe connect callback'
                    end
                end
            rescue Exception => e
                reject(e)
                raise e unless block_given?
            end

            self
        end

        def connect(name, &block)
            return if @closed
            assert_type(String, name, "name must be a String")

            begin
                name = windows_path name if FFI::Platform.windows?
                req = ::MTLibuv::Ext.allocate_request_connect
                ::MTLibuv::Ext.pipe_connect(req, handle, name, callback(:on_connect, req.address))
            rescue Exception => e
                reject(e)
            end

            if block_given?
                @callback = block
            else
                @coroutine = @reactor.defer
                @coroutine.promise.value
            end

            self
        end

        def write2(fd, data = ".", wait: false)
            deferred = @reactor.defer
            if @ipc && !@closed
                begin
                    assert_type(String, data, WRITE_ERROR)
                    assert_type(Handle, fd, WRITE2_ERROR)

                    size         = data.respond_to?(:bytesize) ? data.bytesize : data.size
                    buffer       = ::MTLibuv::Ext.buf_init(FFI::MemoryPointer.from_string(data), size)

                    # local as this variable will be avaliable until the handle is closed
                    req = ::MTLibuv::Ext.allocate_request_write
                    @write_callbacks ||= {}
                    @write_callbacks[req.address] = deferred
                    error = check_result ::MTLibuv::Ext.write2(req, handle, buffer, 1, fd.handle, callback(:write2_complete, req.address))

                    if error
                        @write_callbacks.delete(req.address)
                        ::MTLibuv::Ext.free(req)
                        deferred.reject(error)

                        reject(error)       # close the handle
                    end
                rescue Exception => e
                    deferred.reject(e)  # this write exception may not be fatal
                end
            else
                deferred.reject(TypeError.new('pipe not initialized for interprocess communication'))
            end
            
            if wait
                return deferred.promise if wait == :promise
                deferred.promise.value
            end

            self
        end

        # Windows only
        def pending_instances=(count)
            return 0 if @closed
            assert_type(Integer, count, "count must be an Integer")
            ::MTLibuv::Ext.pipe_pending_instances(handle, count)
        end

        def check_pending(expecting = nil)
            return nil if ::MTLibuv::Ext.pipe_pending_count(handle) <= 0

            pending = ::MTLibuv::Ext.pipe_pending_type(handle).to_sym
            raise TypeError, "IPC expecting #{expecting} and received #{pending}" if expecting && expecting.to_sym != pending

            # Hide the accept logic
            remote = nil
            case pending
            when :tcp
                remote = TCP.new(reactor, handle)
            when :pipe
                remote = Pipe.new(reactor, @ipc, handle)
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
            check_result! ::MTLibuv::Ext.pipe_getsockname(handle, buffer, len)
            buffer.read_string
        end


        private
        

        def accept
            pipe = nil
            begin
                raise RuntimeError, CLOSED_HANDLE_ERROR if @closed
                pipe = Pipe.new(reactor, @ipc, handle)
            rescue Exception => e
                @reactor.log e, 'pipe accept failed'
            end
            if pipe
                @reactor.exec do
                    begin
                        @on_accept.call(pipe)
                    rescue Exception => e
                        @reactor.log e, 'performing pipe accept callback'
                    end
                end
            end
        end

        def on_connect(req, status)
            cleanup_callbacks req.address
            ::MTLibuv::Ext.free(req)
            e = check_result(status)

            @reactor.exec do
                if e
                    reject(e)
                else
                    begin
                        @callback.call(self)
                    rescue Exception => e
                        @reactor.log e, 'performing pipe connected callback'
                    end
                end
            end
        end

        def write2_complete(req, status)
            promise = @write_callbacks.delete(req.address)
            cleanup_callbacks req.address

            ::MTLibuv::Ext.free(req)
            
            @reactor.exec do
                resolve promise, status
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
