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
                # Rubinius fix for promises
                # Anything calling schedule will
                # be delayed a tick outside of promise callbacks on rubinius (see https://github.com/ffi/ffi/issues/279)
                #@reactor_thread = Thread.current # Should work in rubinius 2.0

                # ensure we only execute what was required for this tick
                length = @run_queue.length
                length.times do
                    begin
                        run = @run_queue.pop true  # pop non-block
                        run.call
                    rescue Exception => e
                        @loop.log :error, :next_tick_cb, e
                    end
                end
            end
            @process_queue = SimpleAsync.new(@loop, @queue_proc)

            # Create a next tick timer
            @next_tick = @loop.timer do
                @next_tick_scheduled = false
                @queue_proc.call
            end

            # Create an async call for ending the loop
            @stop_loop = SimpleAsync.new @loop do
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

            begin
                @reactor_thread = Thread.current
                yield  @loop_notify.promise if block_given?
                ::Libuv::Ext.run(@pointer, run_type)  # This is blocking
            ensure
                @reactor_thread = nil
                @run_queue.clear
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
        rescue Exception => e
            @loop.log :warn, :error_lookup_failed, e
            ::Libuv::Error::UNKNOWN.new("error lookup failed for code #{err} #{name} #{msg}")
        end

        # Get a new TCP instance
        # 
        # @return [::Libuv::TCP]
        def tcp
            TCP.new(@loop)
        end

        # Get a new UDP instance
        #
        # @return [::Libuv::UDP]
        def udp
            UDP.new(@loop)
        end

        # Get a new TTY instance
        # 
        # @param fileno [Integer] Integer file descriptor of a tty device
        # @param readable [true, false] Boolean indicating if TTY is readable
        # @return [::Libuv::TTY]
        def tty(fileno, readable = false)
            assert_type(Integer, fileno, "io#fileno must return an integer file descriptor, #{fileno.inspect} given")

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

        # Get a new timer instance
        # 
        # @return [::Libuv::Timer]
        def timer(callback = nil, &blk)
            Timer.new(@loop, callback || blk)
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
        def idle(callback = nil, &block)
            Idle.new(@loop, callback || block)
        end

        # Get a new Async handle
        # 
        # @return [::Libuv::Async]
        def async(callback = nil, &block)
            callback ||= block
            handle = Async.new(@loop)
            handle.progress callback if callback
            handle
        end

        # Queue some work for processing in the libuv thread pool
        #
        # @return [::Libuv::Work]
        # @raise [ArgumentError] if block is not given
        def work(callback = nil, &block)
            Work.new(@loop, callback || block)    # Work is a promise object
        end

        # Get a new FSEvent instance
        # 
        # @return [::Libuv::FSEvent]
        def fs_event(path)
            assert_type(String, path)
            FSEvent.new(@loop, path)
        end


        # Schedule some work to be processed on the event loop (thread safe)
        #
        # @return [nil]
        def schedule(&block)
            assert_block(block)

            if @reactor_thread == Thread.current
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
            if @reactor_thread == Thread.current
                # Create a next tick timer
                if not @next_tick_scheduled
                    @next_tick.start(0)
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
