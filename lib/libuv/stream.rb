module Libuv
    module Stream
        include Handle


        def listen(backlog)
            @listen_deferred = @loop.defer
            begin
                assert_type(Integer, backlog, "backlog must be an Integer")
                check_result! ::Libuv::Ext.listen(handle, Integer(backlog), callback(:on_listen))
            rescue Exception => e
                @listen_deferred.reject(e)
            end
            @listen_deferred.promise
        end

        def accept
            client = loop.send(handle_name)
            check_result! ::Libuv::Ext.accept(handle, client.handle)
            client
        end

        def start_read(&block)
            assert_block(block)

            @read_block = block
            check_result! ::Libuv::Ext.read_start(handle, callback(:on_allocate), callback(:on_read))

            self
        end

        def stop_read
            check_result! ::Libuv::Ext.read_stop(handle)

            self
        end

        def write(data)
            deferred = @loop.defer
            begin
                assert_type(String, data, "data must be a String")

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

                req = nil
                begin
                    @write_callbacks << [deferred, callback]
                    req = ::Libuv::Ext.create_request(:uv_write)
                    check_result! ::Libuv::Ext.write(req, handle, buffer, 1, callback)
                rescue Exception => e
                    @write_callbacks.pop
                    ::Libuv::Ext.free(req)
                    deferred.reject(e)
                end
            rescue Exception => e
                deferred.reject(e)
            end
            deferred.promise
        end

        def shutdown
            @shutdown_deferred = @loop.defer
            begin
                check_result! ::Libuv::Ext.shutdown(::Libuv::Ext.create_request(:uv_shutdown), handle, callback(:on_shutdown))
            rescue Exception => e
                @shutdown_deferred.reject(e)
            end
            @shutdown_deferred.promise
        end

        def readable?
            ::Libuv::Ext.is_readable(handle) > 0
        end

        def writable?
            ::Libuv::Ext.is_writable(handle) > 0
        end


        private


        def on_listen(server, status)
            resolve @listen_deferred, status
            @listen_deferred = nil
        end

        def on_allocate(client, suggested_size)
            ::Libuv::Ext.buf_init(::Libuv::Ext.malloc(suggested_size), suggested_size)
        end

        def on_read(handle, nread, buf)
            e = check_result(nread)
            base = buf[:base]
            unless e
                data = base.read_string(nread)
            end
            ::Libuv::Ext.free(base)
            @read_block.call(e, data)
        end

        def on_shutdown(req, status)
            ::Libuv::Ext.free(req)
            resolve @shutdown_deferred, status
            @shutdown_deferred = nil
        end
    end
end