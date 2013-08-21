module Libuv
    module Stream


        BACKLOG_ERROR = "backlog must be an Integer".freeze
        WRITE_ERROR = "data must be a String".freeze


        def listen(backlog)
            return if @closed
            assert_type(Integer, backlog, BACKLOG_ERROR)
            error = check_result ::Libuv::Ext.listen(handle, Integer(backlog), callback(:on_listen))
            reject(error) if error
        end

        # Starts reading from the handle
        def start_read
            error = check_result ::Libuv::Ext.read_start(handle, callback(:on_allocate), callback(:on_read))
            reject(error) if error
        end

        # Stops reading from the handle
        def stop_read
            error = check_result ::Libuv::Ext.read_stop(handle)
            reject(error) if error
        end

        # Shutsdown the writes on the handle waiting until the last write is complete before triggering the callback
        def shutdown
            error = check_result ::Libuv::Ext.shutdown(::Libuv::Ext.create_request(:uv_shutdown), handle, callback(:on_shutdown))
            reject(error) if error
        end

        def write(data)
            deferred = @loop.defer
            begin
                assert_type(String, data, WRITE_ERROR)

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
                error = check_result ::Libuv::Ext.write(req, handle, buffer, 1, callback)

                if error
                    @write_callbacks.pop
                    ::Libuv::Ext.free(req)
                    deferred.reject(error)

                    reject(error)       # close the handle
                end
            rescue Exception => e
                deferred.reject(e)  # this write exception may not be fatal
            end
            deferred.promise
        end

        def readable?
            ::Libuv::Ext.is_readable(handle) > 0
        end

        def writable?
            ::Libuv::Ext.is_writable(handle) > 0
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

        def on_allocate(client, suggested_size)
            ::Libuv::Ext.buf_init(::Libuv::Ext.malloc(suggested_size), suggested_size)
        end

        def on_read(handle, nread, buf)
            e = check_result(nread)
            base = buf[:base]

            if e
                ::Libuv::Ext.free(base)
                reject(e)
            else
                data = base.read_string(nread)
                ::Libuv::Ext.free(base)
                defer.notify(data)   # stream the data
            end
        end

        def on_shutdown(req, status)
            ::Libuv::Ext.free(req)
            @close_error = check_result(status)
            close
        end
    end
end