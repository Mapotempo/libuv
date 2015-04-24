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
            return if @closed
            assert_type(Integer, backlog, BACKLOG_ERROR)
            error = check_result ::Libuv::Ext.listen(handle, Integer(backlog), callback(:on_listen))
            reject(error) if error
        end

        # Starts reading from the handle
        def start_read
            return if @closed
            error = check_result ::Libuv::Ext.read_start(handle, callback(:on_allocate), callback(:on_read))
            reject(error) if error
        end

        # Stops reading from the handle
        def stop_read
            return if @closed
            error = check_result ::Libuv::Ext.read_stop(handle)
            reject(error) if error
        end

        # Shutsdown the writes on the handle waiting until the last write is complete before triggering the callback
        def shutdown
            return if @closed
            error = check_result ::Libuv::Ext.shutdown(::Libuv::Ext.allocate_request_shutdown, handle, callback(:on_shutdown))
            reject(error) if error
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

        def write(data)
            # NOTE:: Similar to udp.rb -> send
            deferred = @loop.defer
            if !@closed
                begin
                    assert_type(String, data, WRITE_ERROR)

                    buffer1 = ::FFI::MemoryPointer.from_string(data)
                    buffer  = ::Libuv::Ext.buf_init(buffer1, data.respond_to?(:bytesize) ? data.bytesize : data.size)

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
            deferred.promise
        end

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
        end


        private


        def on_listen(server, status)
            e = check_result(status)

            if e
                reject(e)   # is this cause for closing the handle?
            else
                begin
                    @on_listen.call(self)
                rescue Exception => e
                    @loop.log :error, :stream_listen_cb, e
                end
            end
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

            resolve deferred, status
        end

        def on_read(handle, nread, buf)
            e = check_result(nread)
            base = buf[:base]

            if e
                ::Libuv::Ext.free(base)
                # I assume this is desirable behaviour
                if e.is_a? ::Libuv::Error::EOF
                    close   # Close gracefully 
                else
                    reject(e)
                end
            else
                data = base.read_string(nread)
                ::Libuv::Ext.free(base)
                
                if @tls.nil?
                    begin
                        @progress.call data, self
                    rescue Exception => e
                        @loop.log :error, :stream_progress_cb, e
                    end
                else
                    @tls.decrypt(data)
                end
            end
        end

        def on_shutdown(req, status)
            ::Libuv::Ext.free(req)
            @close_error = check_result(status)
            close
        end
    end
end