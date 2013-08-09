require 'thread'

module Libuv
    class Loop
        include Resource, Assertions


        module ClassMethods
            # Get default loop
            # 
            # @return [::Libuv::Loop]
            def default
                create(::Libuv::Ext.default_loop)
            end

            # Create new loop
            # 
            # @return [::Libuv::Loop]
            def new
                create(::Libuv::Ext.loop_new)
            end

            # Create custom loop from pointer
            # 
            # @return [::Libuv::Loop]
            def create(pointer)
                allocate.tap { |i| i.send(:initialize, FFI::AutoPointer.new(pointer, ::Libuv::Ext.method(:loop_delete))) }
            end
        end
        extend ClassMethods


        # Initialize a loop using an FFI::Pointer
        # 
        # @return [::Libuv::Loop]
        def initialize(pointer) # :notnew:
            @pointer = pointer
            @loop = self

            @run_queue = Queue.new
            @on_loop = @loop.async do
                until @run_queue.empty? do
                    begin
                        run = @run_queue.pop true  # pop non-block
                        run.call
                    rescue
                        # TODO:: log error here
                    end
                end
            end
            @on_loop.unref  # Ignore this async handle when deciding if the loop should stop
        end

        # Run the actual event loop. This method will block for the duration of event loop unless
        #   it run inside an existing event loop, where a new thread will be created for it
        #
        # @param run_type [:UV_RUN_DEFAULT, :UV_RUN_ONCE, :UV_RUN_NOWAIT]
        # @yieldparam loop [::Libuv::Loop] Yields the current loop.
        # @return [::Libuv::Q::Promise]
        def run(run_type = :UV_RUN_DEFAULT)
            deferred = @loop.defer

            # Ensure this proc is run on its own thread
            runproc = proc do
                begin
                    Thread.current[:uvloop] = @loop
                    yield @loop if block_given?
                    resolve deferred, ::Libuv::Ext.run(@pointer, run_type)  # This is blocking
                ensure
                    Thread.current[:uvloop] = nil
                end
            end

            # ensure each libuv loop gets its own thread
            if Thread.current[:uvloop].nil?
                runproc.call
            else
                Thread.new { runproc.call }
            end

            deferred.promise
        end


        # Creates a deferred result object for where the result of an operation may only be returned
        #    at some point in the future or is being processed on a different thread
        #
        # @return [::Libuv::Q::Deferred]
        def defer
            Q.defer(@loop)
        end

        # forces loop time update, useful for getting more granular times
        # 
        # @return nil
        def update_time
            ::Libuv::Ext.update_time(@pointer)
        end

        # Get current time in microseconds
        # 
        # @return [Fixnum]
        def now
            ::Libuv::Ext.now(@pointer)
        end

        # Lookup an error code and return is as an error object
        #
        # @param err [Integer] The error code to look up.
        # @return [::Libuv::Error]
        def lookup_error(err)
            name = ::Libuv::Ext.err_name(err)
            msg  = ::Libuv::Ext.strerror(err)

            ::Libuv::Error.const_get(name.to_sym).new(msg)
        rescue
            ::Libuv::Error::UNKNOWN.new("error lookup failed for code: #{err}")
        end

        # Get a new timer instance
        # 
        # @return [::Libuv::Timer]
        def timer
            timer_ptr = ::Libuv::Ext.create_handle(:uv_timer)
            check_result! ::Libuv::Ext.timer_init(@pointer, timer_ptr)

            Timer.new(@loop, timer_ptr)
        end

        # Get a new TCP instance
        # 
        # @return [::Libuv::TCP]
        def tcp
            tcp_ptr = ::Libuv::Ext.create_handle(:uv_tcp)
            check_result! ::Libuv::Ext.tcp_init(@pointer, tcp_ptr)

            TCP.new(@loop, tcp_ptr)
        end

        # Get a new UDP instance
        #
        # @return [::Libuv::UDP]
        def udp
            udp_ptr = ::Libuv::Ext.create_handle(:uv_udp)
            check_result! ::Libuv::Ext.udp_init(@pointer, udp_ptr)

            UV::UDP.new(@loop, udp_ptr)
        end

        # Get a new TTY instance
        # 
        # @param fileno [Integer] Integer file descriptor of a tty device
        # @param readable [true, false] Boolean indicating if TTY is readable
        # @return [::Libuv::TTY]
        # @raise [ArgumentError] if fileno argument is not an Integer or readable is not a Boolean
        def tty(fileno, readable = false)
            assert_type(Integer, fileno, "io#fileno must return an integer file descriptor, #{fileno.inspect} given")
            assert_boolean(readable)

            tty_ptr = ::Libuv::Ext.create_handle(:uv_tty)
            check_result! ::Libuv::Ext.tty_init(@pointer, tty_ptr, fileno, readable ? 1 : 0)

            TTY.new(@loop, tty_ptr)
        end

        # Get a new Pipe instance
        # 
        # @param ipc [true, false]
        #     indicate if a handle will be used for ipc, useful for sharing tcp socket between processes
        # @return [::Libuv::Pipe]
        def pipe(ipc = false)
            assert_boolean(ipc)

            pipe_ptr = ::Libuv::Ext.create_handle(:uv_pipe)
            check_result! ::Libuv::Ext.pipe_init(@pointer, pipe_ptr, ipc ? 1 : 0)

            Pipe.new(@loop, pipe_ptr)
        end

        # Get a new Prepare handle
        # 
        # @return [::Libuv::Prepare]
        def prepare
            prepare_ptr = ::Libuv::Ext.create_handle(:uv_prepare)
            check_result! ::Libuv::Ext.prepare_init(@pointer, prepare_ptr)

            Prepare.new(@loop, prepare_ptr)
        end

        # Get a new Check handle
        # 
        # @return [::Libuv::Check]
        def check
            check_ptr = ::Libuv::Ext.create_handle(:uv_check)
            check_result! ::Libuv::Ext.check_init(@pointer, check_ptr)

            Check.new(@loop, check_ptr)
        end

        # Get a new Idle handle
        # 
        # @return [::Libuv::Idle]
        def idle
            idle_ptr = ::Libuv::Ext.create_handle(:uv_idle)
            check_result! ::Libuv::Ext.idle_init(@pointer, idle_ptr)

            Idle.new(@loop, idle_ptr)
        end

        # Get a new Async handle
        # 
        # @return [::Libuv::Async]
        # @raise [ArgumentError] if block is not given
        def async(&block)
            assert_block(block)

            async_ptr = ::Libuv::Ext.create_handle(:uv_async)
            async     = Async.new(@loop, async_ptr, &block)
            check_result! ::Libuv::Ext.async_init(@pointer, async_ptr, async.callback(:on_async))

            async
        end

        # Queue some work for processing in the libuv thread pool
        #
        # @return [::Libuv::Work]
        # @raise [ArgumentError] if block is not given
        def work(&block)
            assert_block(block)

            deferred = @loop.defer
            Work.new(@loop, deferred, block)    # Work is a promise object
        end

        # Schedule some work to be processed on the event loop
        #
        # @return [nil]
        def schedule(&block)
            assert_block(block)

            if Thread.current[:uvloop] == @loop
                block.call
            else
                @run_queue << block
                @on_loop.call
            end
        end

        # Schedule some work to be processed in the next iteration of the event loop
        #
        # @return [nil]
        def next_tick(&block)
            assert_block(block)

            @run_queue << block
            @on_loop.call
        end

        # Get a new Filesystem instance
        # 
        # @return [::Libuv::Filesystem]
        def fs
            Filesystem.new(self)
        end

        # Get a new FSEvent instance
        # 
        # @return [::Libuv::FSEvent]
        def fs_event(path, &block)
            assert_block(block)

            fs_event_ptr = ::Libuv::Ext.create_handle(:uv_fs_event)
            fs_event     = FSEvent.new(self, fs_event_ptr, &block)
            check_result! ::Libuv::Ext.fs_event_init(@pointer, fs_event_ptr, path, fs_event.callback(:on_fs_event), 0)

            fs_event
        end
    end
end
