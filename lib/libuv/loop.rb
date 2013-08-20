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

            # Create an async call for scheduling work from other threads
            @run_queue = Queue.new
            @queue_proc = proc do
                until @run_queue.empty? do
                    begin
                        run = @run_queue.pop true  # pop non-block
                        run.call
                    rescue
                        # TODO:: log error here
                    end
                end
            end
            @process_queue = @loop.async &@queue_proc

            # Create a next tick timer
            @next_tick = @loop.timer

            # Create an async call for ending the loop
            @stop_loop = @loop.async do
                @process_queue.close
                @stop_loop.close
                @next_tick.close

                ::Libuv::Ext.stop(@pointer)
            end
        end

        def handle; @pointer; end

        # Run the actual event loop. This method will block for the duration of event loop unless
        # it is run inside an existing event loop, where a new thread will be created for it
        #
        # @param run_type [:UV_RUN_DEFAULT, :UV_RUN_ONCE, :UV_RUN_NOWAIT]
        # @yieldparam promise [::Libuv::Loop] Yields a promise that can be used for logging unhandled
        #   exceptions on the loop.
        # @return [::Libuv::Q::Promise]
        def run(run_type = :UV_RUN_DEFAULT)
            @loop_notify = @loop.defer

            # Ensure this proc is run on its own thread
            runproc = proc do
                begin
                    Thread.current[:uvloop] = @loop
                    yield  @loop_notify.promise if block_given?
                    @queue_proc.call    # pre-process any pending procs
                    resolve @loop_notify, ::Libuv::Ext.run(@pointer, run_type)  # This is blocking
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

            @loop
        end


        # Creates a deferred result object for where the result of an operation may only be returned 
        # at some point in the future or is being processed on a different thread (thread safe)
        #
        # @return [::Libuv::Q::Deferred]
        def defer
            Q.defer(@loop)
        end

        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved. (thread safe)
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise that will be resolved with an array of values,
        #   each value corresponding to the promise at the same index in the `promises` array. If any of
        #   the promises is resolved with a rejection, this resulting promise will be resolved with the
        #   same rejection.
        def all(*promises)
            Q.all(@loop, *promises)
        end

        #
        # Combines multiple promises into a single promise that is resolved when any of the input
        # promises are resolved.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise
        def any(*promises)
            Q.any(@loop, *promises)
        end

        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved or rejected.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise that will be resolved with an array of values,
        #   each [result, wasResolved] value pair corresponding to a at the same index in the `promises` array.
        def finally(*promises)
            Q.finally(@loop, *promises)
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
        rescue Exception
            ::Libuv::Error::UNKNOWN.new("error lookup failed for code: #{err}")
        end

        # Get a new timer instance
        # 
        # @return [::Libuv::Timer]
        def timer
            Timer.new(@loop)
        end

        # Get a new TCP instance
        # 
        # @return [::Libuv::TCP]
        def tcp
            TCP.new(@loop, tcp_ptr)
        end

        # Get a new UDP instance
        #
        # @return [::Libuv::UDP]
        def udp
            UDP.new(@loop, udp_ptr)
        end

        # Get a new TTY instance
        # 
        # @param fileno [Integer] Integer file descriptor of a tty device
        # @param readable [true, false] Boolean indicating if TTY is readable
        # @return [::Libuv::TTY]
        def tty(fileno, readable = false)
            TTY.new(@loop, fileno, readable)
        end

        # Get a new Pipe instance
        # 
        # @param ipc [true, false]
        #     indicate if a handle will be used for ipc, useful for sharing tcp socket between processes
        # @return [::Libuv::Pipe]
        def pipe(ipc = false)
            Pipe.new(@loop, ipc)
        end

        # Get a new Prepare handle
        # 
        # @return [::Libuv::Prepare]
        def prepare
            Prepare.new(@loop)
        end

        # Get a new Check handle
        # 
        # @return [::Libuv::Check]
        def check
            Check.new(@loop)
        end

        # Get a new Idle handle
        # 
        # @return [::Libuv::Idle]
        def idle
            Idle.new(@loop)
        end

        # Get a new Async handle
        # 
        # @return [::Libuv::Async]
        # @raise [ArgumentError] if block is not given
        def async(callback = nil, &block)
            Async.new(@loop, callback || block)
        end

        # Queue some work for processing in the libuv thread pool
        #
        # @return [::Libuv::Work]
        # @raise [ArgumentError] if block is not given
        def work(callback = nil, &block)
            Work.new(@loop, callback || block)    # Work is a promise object
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


        # Schedule some work to be processed on the event loop (thread safe)
        #
        # @return [nil]
        def schedule(&block)
            assert_block(block)

            if Thread.current[:uvloop] == @loop
                block.call
            else
                @run_queue << block
                @process_queue.call
            end
        end

        # Schedule some work to be processed in the next iteration of the event loop (thread safe)
        #
        # @return [nil]
        def next_tick(&block)
            assert_block(block)

            @run_queue << block
            if Thread.current[:uvloop] == @loop
                # Create a next tick timer
                if not @next_tick_scheduled
                    @next_tick.start(0) do
                        @next_tick_scheduled = false
                        @queue_proc.call
                    end
                    @next_tick_scheduled = true
                end
            else
                @process_queue.call
            end
        end

        # Notifies the loop there was an event that should be logged
        #
        # @param level [Symbol] the error level (info, warn, error etc)
        # @param id [Object] some kind of identifying information
        # @param *args [*args] any additional information
        # @return [nil]
        def log(level, id, *args)
            @loop_notify.notify(level, id, *args)
        end

        # Closes handles opened by the loop class and completes the current loop iteration (thread safe)
        # 
        # @return [nil]
        def stop
            @stop_loop.call
        end
    end
end
