module Libuv
    module Stream


        def self.included(base)
            base.define_callback function: :on_listen,      params: [:pointer, :int]
            base.define_callback function: :write_complete, params: [:pointer, :int]
            base.define_callback function: :on_shutdown,    params: [:pointer, :int]

            base.define_callback function: :on_allocate, params: [:pointer, :size_t, Ext::UvBuf.by_ref]
            base.define_callback function: :on_read,     params: [:pointer, :ssize_t, Ext::UvBuf.by_ref]
        end



        BACKLOG_ERROR = "backlog must be an Integer".freeze
        WRITE_ERROR = "data must be a String".freeze
        STREAM_CLOSED_ERROR = "unable to write to a closed stream".freeze
        CLOSED_HANDLE_ERROR = "handle closed before accept called".freeze


        def listen(backlog)
            return self if @closed
            assert_type(Integer, backlog, BACKLOG_ERROR)
            error = check_result ::Libuv::Ext.listen(handle, Integer(backlog), callback(:on_listen))
            reject(error) if error
            self
        end

        # Starts reading from the handle
        def start_read
            return self if @closed
            error = check_result ::Libuv::Ext.read_start(handle, callback(:on_allocate), callback(:on_read))
            reject(error) if error
            self
        end

        # Stops reading from the handle
        def stop_read
            return self if @closed
            error = check_result ::Libuv::Ext.read_stop(handle)
            reject(error) if error
            self
        end
        alias_method :close_read, :stop_read

        # Shutsdown the writes on the handle waiting until the last write is complete before triggering the callback
        def shutdown
            return self if @closed
            req = ::Libuv::Ext.allocate_request_shutdown
            error = check_result ::Libuv::Ext.shutdown(req, handle, callback(:on_shutdown, req.address))
            reject(error) if error
            self
        end

        def try_write(data)
            assert_type(String, data, WRITE_ERROR)

            buffer1 = ::FFI::MemoryPointer.from_string(data)
            buffer  = ::Libuv::Ext.buf_init(buffer1, data.respond_to?(:bytesize) ? data.bytesize : data.size)

            result = ::Libuv::Ext.try_write(handle, buffer, 1)
            buffer1.free

            error = check_result result
            raise error if error
            return result
        end

        def write(data, wait: false)
            # NOTE:: Similar to udp.rb -> send
            deferred = @reactor.defer
            if !@closed
                begin
                    assert_type(String, data, WRITE_ERROR)

                    buffer1 = ::FFI::MemoryPointer.from_string(data)
                    buffer  = ::Libuv::Ext.buf_init(buffer1, data.bytesize)

                    # local as this variable will be available until the handle is closed
                    @write_callbacks ||= {}
                    req = ::Libuv::Ext.allocate_request_write
                    @write_callbacks[req.address] = [deferred, buffer1]
                    error = check_result ::Libuv::Ext.write(req, handle, buffer, 1, callback(:write_complete, req.address))

                    if error
                        @write_callbacks.delete req.address
                        cleanup_callbacks req.address

                        ::Libuv::Ext.free(req)
                        buffer1.free
                        deferred.reject(error)

                        reject(error)       # close the handle
                    end
                rescue => e
                    deferred.reject(e)  # this write exception may not be fatal
                end
            else
                deferred.reject(RuntimeError.new(STREAM_CLOSED_ERROR))
            end

            if wait
                return deferred.promise if wait == :promise
                co deferred.promise
            end

            self
        end
        alias_method :puts, :write
        alias_method :write_nonblock, :write

        def readable?
            return false if @closed
            ::Libuv::Ext.is_readable(handle) > 0
        end

        def writable?
            return false if @closed
            ::Libuv::Ext.is_writable(handle) > 0
        end

        def progress(callback = nil, &blk)
            @progress = callback || blk
            self
        end

        # Very basic IO emulation, in no way trying to be exact
        def read(maxlen = nil, outbuf = nil)
            raise ::EOFError.new('socket closed') if @closed
            @read_defer = @reactor.defer

            if @read_buffer.nil?
                start_read
                @read_buffer = String.new
                self.finally do
                    @read_defer.reject(::EOFError.new('socket closed'))
                end
            end

            if check_read_buffer(maxlen, outbuf, @read_defer)
                progress do |data|
                    @read_buffer << data
                    check_read_buffer(maxlen, outbuf, @read_defer)
                end
            end

            co @read_defer.promise
        end
        alias_method :read_nonblock, :read

        # These are here purely for compatibility with rack hijack IO
        def close_write; end
        def flush
            raise ::EOFError.new('socket closed') if @closed

            @flush_defer = @reactor.defer
            check_flush_buffer
            co @flush_defer.promise
        end


        private


        def check_read_buffer(maxlen, outbuf, defer)
            if maxlen && @read_buffer.bytesize >= maxlen
                if outbuf
                    outbuf << @read_buffer[0...maxlen]
                    defer.resolve outbuf
                else
                    defer.resolve @read_buffer[0...maxlen]
                end
                @read_buffer = @read_buffer[maxlen..-1]
                progress do |data|
                    @read_buffer << data
                end
                false
            elsif maxlen.nil?
                defer.resolve @read_buffer
                @read_buffer = String.new
                progress do |data|
                    @read_buffer << data
                end
                false
            else
                true
            end
        end

        def check_flush_buffer
            if @flush_defer && (@write_callbacks.nil? || @write_callbacks.empty?) && (@pending_writes.nil? || @pending_writes.empty?) && @pending_write.nil?
                @flush_defer.resolve(nil)
                @flush_defer = nil
            end
        end


        def on_listen(server, status)
            e = check_result(status)

            ::Fiber.new {
                if e
                    reject(e)   # is this cause for closing the handle?
                else
                    begin
                        @on_listen.call(self)
                    rescue Exception => e
                        @reactor.log e, 'performing stream listening callback'
                    end
                end
            }.resume
        end

        def on_allocate(client, suggested_size, buffer)
            buffer[:len] = suggested_size
            buffer[:base] = ::Libuv::Ext.malloc(suggested_size)
        end

        def write_complete(req, status)
            deferred, buffer1 = @write_callbacks.delete req.address
            cleanup_callbacks req.address

            ::Libuv::Ext.free(req)
            buffer1.free

            ::Fiber.new {
                resolve deferred, status
                check_flush_buffer if @flush_defer
            }.resume
        end

        def on_read(handle, nread, buf)
            e = check_result(nread)
            base = buf[:base]

            if e
                ::Libuv::Ext.free(base)

                ::Fiber.new { 
                    # I assume this is desirable behaviour
                    if e.is_a? ::Libuv::Error::EOF
                        close   # Close gracefully 
                    else
                        reject(e)
                    end
                }.resume
            else
                data = base.read_string(nread)
                ::Libuv::Ext.free(base)
                
                ::Fiber.new {
                    if @tls.nil?
                        begin
                            @progress.call data, self
                        rescue Exception => e
                            @reactor.log e, 'performing stream read callback'
                        end
                    else
                        @tls.decrypt(data)
                    end
                }.resume
            end
        end

        def on_shutdown(req, status)
            cleanup_callbacks(req.address)
            ::Libuv::Ext.free(req)
            @close_error = check_result(status)

            ::Fiber.new { close }.resume
        end
    end
end