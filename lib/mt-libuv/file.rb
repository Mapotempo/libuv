# frozen_string_literal: true

module MTLibuv
    class File < Q::DeferredPromise
        include Assertions, Resource, Listener, FsChecks


        fs_params = {
            params: [Ext::FsRequest.by_ref],
            lookup: :fs_lookup
        }
        define_callback function: :on_open, **fs_params
        define_callback function: :on_close, **fs_params
        define_callback function: :on_read, **fs_params
        define_callback function: :on_write, **fs_params
        define_callback function: :on_sync, **fs_params
        define_callback function: :on_datasync, **fs_params
        define_callback function: :on_truncate, **fs_params
        define_callback function: :on_utime, **fs_params
        define_callback function: :on_chmod, **fs_params
        define_callback function: :on_chown, **fs_params
        define_callback function: :on_stat, **fs_params


        EOF = "0\r\n\r\n"
        CRLF = "\r\n"


        attr_reader :fileno, :closed


        def initialize(thread, path, flags = 0, mode: 0, &block)
            super(thread, thread.defer)

            @fileno = -1
            @closed = true 
            @path, @flags, @mode = path, flags, mode
            @request_refs = {}

            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check @defer, request, ::MTLibuv::Ext.fs_open(@reactor, request, @path, @flags, @mode, callback(:on_open, request.address))

            if block_given?
                self.progress &block
            else
                @coroutine = @reactor.defer
                @coroutine.promise.value
            end
        end

        def close
            @closed = true
            request = ::MTLibuv::Ext.allocate_request_fs
            pre_check(@defer, request, ::MTLibuv::Ext.fs_close(@reactor.handle, request, @fileno, callback(:on_close, request.address)))
            self
        end

        def read(length, offset = 0, wait: true)
            assert_type(Integer, length, "length must be an Integer")
            assert_type(Integer, offset, "offset must be an Integer")
            deferred = @reactor.defer

            buffer1 = FFI::MemoryPointer.new(length)
            buffer  = ::MTLibuv::Ext.buf_init(buffer1, length)
            request = ::MTLibuv::Ext.allocate_request_fs

            @request_refs[request.address] = [deferred, buffer1]

            promise = pre_check(deferred, request, ::MTLibuv::Ext.fs_read(@reactor.handle, request, @fileno, buffer, 1, offset, callback(:on_read, request.address)))
            wait ? promise.value : promise
        end

        def write(data, offset = 0, wait: true)
            assert_type(String, data, "data must be a String")
            assert_type(Integer, offset, "offset must be an Integer")
            deferred = @reactor.defer

            length = data.respond_to?(:bytesize) ? data.bytesize : data.size

            buffer1 = FFI::MemoryPointer.from_string(data)
            buffer  = ::MTLibuv::Ext.buf_init(buffer1, length)
            request = ::MTLibuv::Ext.allocate_request_fs

            @request_refs[request.address] = [deferred, buffer1]

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_write(@reactor.handle, request, @fileno, buffer, 1, offset, callback(:on_write, request.address)))
        end

        def sync(wait: false)
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_fsync(@reactor.handle, request, @fileno, callback(:on_sync, request.address)))
        end

        def datasync(wait: false)
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_fdatasync(@reactor.handle, request, @fileno, callback(:on_datasync, request.address)))
        end

        def truncate(offset, wait: true)
            assert_type(Integer, offset, "offset must be an Integer")
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_ftruncate(@reactor.handle, request, @fileno, offset, callback(:on_truncate, request.address)))
        end

        def utime(atime:, mtime:, wait: true)
            assert_type(Integer, atime, "atime must be an Integer")
            assert_type(Integer, mtime, "mtime must be an Integer")
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            promise = pre_check deferred, request, ::MTLibuv::Ext.fs_futime(@reactor.handle, request, @fileno, atime, mtime, callback(:on_utime, request.address))
            wait ? promise.value : promise
        end

        def chmod(mode, wait: true)
            assert_type(Integer, mode, "mode must be an Integer")
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_fchmod(@reactor.handle, request, @fileno, mode, callback(:on_chmod, request.address)))
        end

        def chown(uid:, gid:, wait: true)
            assert_type(Integer, uid, "uid must be an Integer")
            assert_type(Integer, gid, "gid must be an Integer")
            deferred = @reactor.defer

            request = ::MTLibuv::Ext.allocate_request_fs
            @request_refs[request.address] = deferred

            respond wait, pre_check(deferred, request, ::MTLibuv::Ext.fs_fchown(@reactor.handle, request, @fileno, uid, gid, callback(:on_chown, request.address)))
        end

        def send_file(stream, using: :raw, chunk_size: 4096, wait: true)
            @transmit_failure ||= proc { |reason| @sending_file.reject(reason) }
            @start_transmit ||= proc { |stats|
                @file_stream_total = stats[:st_size]
                next_chunk
            }
            @transmit_data ||= proc { |data| transmit_data(data) }

            @sending_file = @reactor.defer
            @file_stream = stream
            @file_stream_type = using
            @file_chunk_size = chunk_size
            @file_chunk_count = 0

            stat(wait: false).then @start_transmit, @transmit_failure
            
            promise = @sending_file.promise
            promise.finally { clean_up_send }
            respond wait, promise
        end


        private


        ##
        # File transmit functions -------------
        def transmit_data(data)
            @file_chunk_count += 1
            if @file_stream_type == :http
                resp = String.new
                resp << data.bytesize.to_s(16) << CRLF
                resp << data
                resp << CRLF
                data = resp
            end
            @file_stream.write(data, wait: :promise).then(proc { next_chunk }, @transmit_failure)
            nil
        end

        def next_chunk
            next_size = @file_chunk_size
            next_offset = @file_chunk_size * @file_chunk_count
            
            if next_offset >= @file_stream_total
                if @file_stream_type == :http
                    @file_stream.write(EOF, wait: :promise).then(proc {
                        @sending_file.resolve(@file_stream_total)
                    }, @transmit_failure)
                else
                    @sending_file.resolve(@file_stream_total)
                end
            else
                if next_offset + next_size > @file_stream_total
                    next_size = @file_stream_total - next_offset
                end
                read(next_size, next_offset, wait: false).then(@transmit_data, @transmit_failure)
            end
            nil
        end

        def clean_up_send
            @sending_file = nil
            @file_stream = nil
            @file_stream_type = nil
            @file_chunk_size = nil
            @file_chunk_count = nil
            @file_stream_total = nil
        end
        # -------------------------------------
        ##


        def on_open(req)
            if post_check(req, @defer)
                @fileno = req[:result]
                cleanup(req)
                @closed = false
                @reactor.exec { @defer.notify(self) }

                if @coroutine
                    @coroutine.resolve(nil)
                    @coroutine = nil
                end
            end
        end

        def on_close(req)
            if post_check(req, @defer)
                cleanup(req)
                @reactor.exec { @defer.resolve(nil) }
            end
        end

        def on_read(req)
            deferred, buffer1 = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                data = buffer1.read_string(req[:result])
                cleanup(req)
                @reactor.exec { deferred.resolve(data) }
            end
        end

        def on_write(req)
            deferred, buffer1 = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_sync(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_datasync(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_truncate(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_utime(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_chmod(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end

        def on_chown(req)
            deferred = @request_refs.delete req.to_ptr.address
            if post_check(req, deferred)
                cleanup(req)
                @reactor.exec { deferred.resolve(nil) }
            end
        end
    end
end