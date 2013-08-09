require 'atomic'
require 'thread_safe'


module Libuv
    module Stream
        include Handle


        WRITEBACKS = ThreadSafe::Cache.new
        @@write_id = Atomic.new(0)


        def listen(backlog)
            begin
                @listen_deferred = @loop.defer
                assert_type(Integer, backlog, "backlog must be an Integer")
                check_result! ::Libuv::Ext.listen(handle, Integer(backlog), callback(:on_listen))
            rescue Exception => e
                @listen_deferred.reject(e)
            ensure
                @listen_deferred.promise
            end
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

                #
                # Shared write id across all event loops
                #
                callback_id = 0
                @@write_id.update { |val|
                    callback_id = val
                    val + 1
                }

                #
                # create the curried callback
                #
                callback = FFI::Function.new(:void, [:pointer, :int]) do |req, status|
                    ::Libuv::Ext.free(req)
                    promise = WRITEBACKS.delete(callback_id)[0]
                    resolve promise, status
                end

                begin
                    WRITEBACKS[callback_id] = [deferred, callback]
                    check_result! ::Libuv::Ext.write(::Libuv::Ext.create_request(:uv_write), handle, buffer, 1, callback)
                rescue Exeption => e
                    WRITEBACKS.delete(callback_id)
                    ::Libuv::Ext.free(req)
                    raise e
                end
            rescue Exeption => e
                deferred.reject(e)
            ensure
                deferred.promise
            end
        end

        def shutdown
            begin
                @shutdown_deferred = @loop.defer
                check_result! ::Libuv::Ext.shutdown(::Libuv::Ext.create_request(:uv_shutdown), handle, callback(:on_shutdown))
            rescue Exeption => e
                @shutdown_deferred.reject(e)
            ensure
                @shutdown_deferred.promise
            end
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