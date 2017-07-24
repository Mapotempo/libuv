# frozen_string_literal: true

module Libuv
    class Spawn < Handle
        define_callback function: :on_exit, params: [:pointer, :int64, :int]

        attr_reader :stdin, :stdout, :stderr

        # @param reactor [::Libuv::Reactor] reactor this timer will be associated
        # @param callback [Proc] callback to be called when the timer is triggered
        def initialize(reactor, cmd, working_dir: '.', args: [], env: nil, flags: 0, mode: :capture)
            @reactor = reactor

            process_ptr = ::Libuv::Ext.allocate_handle_process
            @options = Ext::UvProcessOptions.new

            # Configure IO objects
            @io_obj = Ext::StdioObjs.new
            case mode.to_sym
            when :capture
                @stdin  = @reactor.pipe
                @stdout = @reactor.pipe
                @stderr = @reactor.pipe
                @io_obj[:stdin] = build_stdio(:CREATE_READABLE_PIPE, pipe: @stdin)
                @io_obj[:stdout] = build_stdio(:CREATE_WRITABLE_PIPE, pipe: @stdout)
                @io_obj[:stderr] = build_stdio(:CREATE_WRITABLE_PIPE, pipe: @stderr)
            when :ignore
                @io_obj[:stdin] = build_stdio(:UV_IGNORE)
                @io_obj[:stdout] = build_stdio(:UV_IGNORE)
                @io_obj[:stderr] = build_stdio(:UV_IGNORE)
            when :inherit
                @io_obj[:stdin] = build_stdio(:UV_INHERIT_FD, fd: 0)
                @io_obj[:stdout] = build_stdio(:UV_INHERIT_FD, fd: 1)
                @io_obj[:stderr] = build_stdio(:UV_INHERIT_FD, fd: 2)
            end

            # Configure arguments
            @cmd = FFI::MemoryPointer.from_string(cmd)
            @args = args.map { |arg| FFI::MemoryPointer.from_string(arg) }
            @args.unshift(@cmd)
            @args_ptr = FFI::MemoryPointer.new(:pointer, @args.length + 1)
            @args_ptr.write_array_of_pointer(@args)

            # Configure environment
            if env
                @env = env.map { |e| FFI::MemoryPointer.from_string(e) }
                @env_ptr = FFI::MemoryPointer.new(:pointer, @env.length + 1)
                @env_ptr.write_array_of_pointer(@env)
            end

            @working_dir = FFI::MemoryPointer.from_string(working_dir)

            # Apply the options
            @options[:exit_cb] = callback(:on_exit, process_ptr.address)
            @options[:file] = @cmd
            @options[:args] = @args_ptr
            @options[:env] = @env_ptr
            @options[:cwd] = @working_dir
            @options[:flags] = 0
            @options[:stdio_count] = 3
            @options[:stdio] = @io_obj

            error = check_result(::Libuv::Ext.spawn(reactor.handle, process_ptr, @options))
            super(process_ptr, error)
        end

        def kill(signal = 2)
            return self if @closed
            ::Libuv::Ext.process_kill(handle, signal)
            self
        end


        private


        def build_stdio(flags, pipe: nil, fd: nil)
            io = Ext::UvStdioContainer.new
            io[:flags] = flags
            if pipe
                io[:data][:pipe_handle] = pipe.handle
            elsif fd
                io[:data][:fd] = fd
            end
            io
        end

        def on_exit(handle, exit_status, term_signal)
            ::Fiber.new {
                if exit_status == 0
                    @defer.resolve(term_signal)
                else
                    err = ::Libuv::Error::ProcessExitCode.new "Non-zero exit code returned #{exit_status}"
                    err.exit_status = exit_status
                    err.term_signal = term_signal
                    @defer.reject(err)
                end

                if @stdin
                    @reactor.next_tick do
                        @stdin.close
                        @stdout.close
                        @stderr.close
                    end
                end
            }.resume
        end
    end
end
