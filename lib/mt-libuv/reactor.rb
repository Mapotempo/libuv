# frozen_string_literal: true

require 'thread'

module MTLibuv
    class Reactor
        include Resource, Assertions
        extend Accessors


        LIBUV_MIN_POOL = ENV['LIBUV_MIN_POOL'] || 8
        LIBUV_MAX_POOL = ENV['LIBUV_MAX_POOL'] || 40
        LIBUV_MAX_QUEUE = ENV['LIBUV_MAX_QUEUE'] || 50000
        THREAD_POOL = ::Concurrent::ThreadPoolExecutor.new(
            min_threads: LIBUV_MIN_POOL,
            max_threads: LIBUV_MAX_POOL,
            max_queue: LIBUV_MAX_QUEUE
        )
        CRITICAL = ::Mutex.new


        module ClassMethods
            # Get default reactor
            #
            # @return [::MTLibuv::Reactor]
            def default
                return @default unless @default.nil?
                CRITICAL.synchronize {
                    return @default ||= create(::MTLibuv::Ext.default_loop)
                }
            end

            # Create new MTLibuv reactor
            #
            # @return [::MTLibuv::Reactor]
            def new(&blk)
                memory = ::MTLibuv::Ext::LIBC.malloc(::MTLibuv::Ext.loop_size)
                ::MTLibuv::Ext.loop_init(memory)

                thread = create(memory)
                if block_given?
                    ::Thread.new do
                        thread.run &blk
                    end
                end
                thread
            end

            # Build a Ruby MTLibuv reactor from an existing reactor pointer
            #
            # @return [::MTLibuv::Reactor]
            def create(pointer)
                allocate.tap { |i| i.send(:initialize, pointer) }
            end

            # Checks for the existence of a reactor on the current thread
            #
            # @return [::MTLibuv::Reactor | nil]
            def current
                Thread.current.thread_variable_get(:reactor)
            end
        end
        extend ClassMethods


        # Initialize a reactor using an FFI::Pointer to a libuv reactor
        def initialize(pointer) # :notnew:
            @pointer = pointer
            @reactor = self
            @run_count = 0
            @ref_count = 0
            @fiber_pool = FiberPool.new(self)

            # Create an async call for scheduling work from other threads
            @run_queue = Queue.new
            @process_queue = @reactor.async { process_queue_cb }
            @process_queue.unref

            # Create a next tick timer
            @next_tick = @reactor.timer { next_tick_cb }
            @next_tick.unref

            # Create an async call for ending the reactor
            @stop_reactor = @reactor.async { stop_cb }
            @stop_reactor.unref

            # MTLibuv can prevent the application shutting down once the main thread has ended
            # The addition of a prepare function prevents this from happening.
            @reactor_prep = prepare {}
            @reactor_prep.unref
            @reactor_prep.start

            # LibUV ingnores program interrupt by default.
            # We provide normal behaviour and allow this to be overriden
            @on_signal = []
            sig_callback = proc { signal_cb }
            self.signal(:INT, &sig_callback).unref
            self.signal(:HUP, &sig_callback).unref
            self.signal(:TERM, &sig_callback).unref

            # Notify of errors
            @throw_on_exit = nil
            @reactor_notify_default = @reactor_notify = proc { |error|
                @throw_on_exit = error
            }
            @fiber_pool.on_error &@reactor_notify
        end

        attr_reader :run_count, :fiber_pool


        protected


        def stop_cb
            return unless @reactor_running
            Thread.current.thread_variable_set(:reactor, nil)
            @reactor_running = false

            ::MTLibuv::Ext.stop(@pointer)
        end

        def signal_cb
            if @on_signal.empty?
                stop_cb
            else
                @on_signal.each(&:call)
            end
        end

        def next_tick_cb
            @next_tick_scheduled = false
            @next_tick.unref
            process_queue_cb
        end

        def process_queue_cb
            # ensure we only execute what was required for this tick
            length = @run_queue.length
            update_time
            length.times do
                # This allows any item to pause its execution without effecting this loop
                @fiber_pool.exec { process_item }
            end
        end

        def process_item
            begin
                run = @run_queue.pop true  # pop non-block
                run.call
            rescue Exception => e
                @reactor.log e, 'performing next tick callback'
            end
        end


        public


        # Overwrite as errors in jRuby can literally hang VM when inspecting
        # as many many classes will reference this class
        def inspect
            "#<#{self.class}:0x#{self.__id__.to_s(16)} NT=#{@run_queue.length}>"
        end


        def handle; @pointer; end

        # Run the actual event reactor. This method will block until the reactor is stopped.
        #
        # @param run_type [:UV_RUN_DEFAULT, :UV_RUN_ONCE, :UV_RUN_NOWAIT]
        # @yieldparam promise [::MTLibuv::Q::Promise] Yields a promise that can be used for logging unhandled
        #   exceptions on the reactor.
        def run(run_type = :UV_RUN_DEFAULT)
            if not @reactor_running
                begin
                    @reactor_running = true
                    raise 'only one reactor allowed per-thread' if Thread.current.thread_variable_get(:reactor)

                    Thread.current.thread_variable_set(:reactor, @reactor)
                    @throw_on_exit = nil
                    update_time
                    @fiber_pool.reset
                    @fiber_pool.exec { yield @reactor } if block_given?
                    @run_count += 1
                    ::MTLibuv::Ext.run(@pointer, run_type)  # This is blocking
                ensure
                    Thread.current.thread_variable_set(:reactor, nil)
                    @reactor_running = false
                    @run_queue.clear
                end

                # Raise the last unhandled error to occur on the reactor thread
                raise @throw_on_exit if @throw_on_exit

            elsif block_given?
                if reactor_thread?
                    update_time
                    yield @reactor
                else
                    raise 'reactor already running on another thread'
                end
            end

            @reactor
        end

        # Execute the provided block of code in a fiber from the pool
        def exec
            @fiber_pool.exec { yield }
        end

        # Prevents the reactor loop from stopping
        def ref
            if reactor_thread? && reactor_running?
                @process_queue.ref if @ref_count == 0
                @ref_count += 1
            end
        end

        # Allows the reactor loop to stop
        def unref
            if reactor_thread? && reactor_running? && @ref_count > 0
                @ref_count -= 1
                @process_queue.unref if @ref_count == 0
            end
        end

        # Return the number of active handles in the event loop
        def active_handles
            uvloop = Ext::UvLoop.new @pointer
            uvloop[:active_handles]
        end


        # Provides a promise notifier for receiving un-handled exceptions
        #
        # @return [::MTLibuv::Q::Promise]
        def notifier(&block)
            @reactor_notify = if block_given?
                block
            else
                @reactor_notify_default
            end
            self
        end

        # Creates a deferred result object for where the result of an operation may only be returned
        # at some point in the future or is being processed on a different thread (thread safe)
        #
        # @return [::MTLibuv::Q::Deferred]
        def defer
            Q.defer(@reactor)
        end

        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved. (thread safe)
        #
        # @param *promises [::MTLibuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::MTLibuv::Q::Promise] Returns a single promise that will be resolved with an array of values,
        #   each value corresponding to the promise at the same index in the `promises` array. If any of
        #   the promises is resolved with a rejection, this resulting promise will be resolved with the
        #   same rejection.
        def all(*promises)
            Q.all(@reactor, *promises)
        end

        #
        # Combines multiple promises into a single promise that is resolved when any of the input
        # promises are resolved.
        #
        # @param *promises [::MTLibuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::MTLibuv::Q::Promise] Returns a single promise
        def any(*promises)
            Q.any(@reactor, *promises)
        end

        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved or rejected.
        #
        # @param *promises [::MTLibuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::MTLibuv::Q::Promise] Returns a single promise that will be resolved with an array of values,
        #   each [result, wasResolved] value pair corresponding to a at the same index in the `promises` array.
        def finally(*promises)
            Q.finally(@reactor, *promises)
        end

        # Creates a promise that is resolved as rejected with the specified reason. This api should be
        # used to forward rejection in a chain of promises. If you are dealing with the last promise in
        # a promise chain, you don't need to worry about it.
        def reject(reason)
            Q.reject(@reactor, reason)
        end

        # forces reactor time update, useful for getting more granular times
        #
        # @return nil
        def update_time
            ::MTLibuv::Ext.update_time(@pointer)
            self
        end

        # Get current time in milliseconds
        #
        # @return [Integer]
        def now
            ::MTLibuv::Ext.now(@pointer)
        end

        # Lookup an error code and return is as an error object
        #
        # @param err [Integer] The error code to look up.
        # @return [::MTLibuv::Error]
        def lookup_error(err)
            name = ::MTLibuv::Ext.err_name(err)

            if name
                msg  = ::MTLibuv::Ext.strerror(err)
                ::MTLibuv::Error.const_get(name.to_sym).new("#{msg}, #{name}:#{err}")
            else
                # We want a back-trace in this case
                raise "error lookup failed for code #{err}"
            end
        rescue Exception => e
            @reactor.log e, 'performing error lookup'
            e
        end

        def sleep(msecs)
            fiber = Fiber.current
            time = timer {
                time.close
                fiber.resume
            }.start(msecs)
            Fiber.yield
        end

        # Get a new TCP instance
        #
        # @return [::MTLibuv::TCP]
        def tcp(**opts, &callback)
            TCP.new(@reactor, progress: callback, **opts)
        end

        # Get a new UDP instance
        #
        # @return [::MTLibuv::UDP]
        def udp(**opts, &callback)
            UDP.new(@reactor, progress: callback, **opts)
        end

        # Get a new TTY instance
        #
        # @param fileno [Integer] Integer file descriptor of a tty device
        # @param readable [true, false] Boolean indicating if TTY is readable
        # @return [::MTLibuv::TTY]
        def tty(fileno, readable = false)
            assert_type(Integer, fileno, "io#fileno must return an integer file descriptor, #{fileno.inspect} given")

            TTY.new(@reactor, fileno, readable)
        end

        # Get a new Pipe instance
        #
        # @param ipc [true, false] indicate if a handle will be used for ipc, useful for sharing tcp socket between processes
        # @return [::MTLibuv::Pipe]
        def pipe(ipc = false)
            Pipe.new(@reactor, ipc)
        end

        # Get a new timer instance
        #
        # @param callback [Proc] the callback to be called on timer trigger
        # @return [::MTLibuv::Timer]
        def timer(&block)
            handle = Timer.new(@reactor)
            handle.progress &block if block_given?
            handle
        end

        # Get a new Prepare handle
        #
        # @return [::MTLibuv::Prepare]
        def prepare(&block)
            handle = Prepare.new(@reactor)
            handle.progress &block if block_given?
            handle
        end

        # Get a new Check handle
        #
        # @return [::MTLibuv::Check]
        def check(&block)
            handle = Check.new(@reactor)
            handle.progress &block if block_given?
            handle
        end

        # Get a new Idle handle
        #
        # @param callback [Proc] the callback to be called on idle trigger
        # @return [::MTLibuv::Idle]
        def idle(&block)
            handle = Idle.new(@reactor)
            handle.progress &block if block_given?
            handle
        end

        # Get a new Async handle
        #
        # @return [::MTLibuv::Async]
        def async(&block)
            handle = Async.new(@reactor)
            handle.progress &block if block_given?
            handle
        end

        # Get a new signal handler
        #
        # @return [::MTLibuv::Signal]
        def signal(signum = nil, &block)
            handle = Signal.new(@reactor)
            handle.progress &block if block_given?
            handle.start(signum) if signum
            handle
        end

        # Allows user defined behaviour when sig int is received
        def on_program_interrupt(&callback)
            @on_signal << callback
            self
        end

        # Queue some work for processing in the libuv thread pool
        #
        # @param callback [Proc] the callback to be called in the thread pool
        # @return [::MTLibuv::Work]
        # @raise [ArgumentError] if block is not given
        def work
            ref
            d = defer
            THREAD_POOL.post do
                begin
                    d.resolve(yield)
                rescue Exception => e
                    d.reject(e)
                end
            end
            promise = d.promise
            promise.finally { unref }
            promise
        end

        # Lookup a hostname
        #
        # @param hostname [String] the domain name to lookup
        # @param port [Integer, String] the service being connected too
        # @param callback [Proc] the callback to be called on success
        # @return [::MTLibuv::Dns]
        def lookup(hostname, hint = :IPv4, port = 9, wait: true, &block)
            dns = Dns.new(@reactor, hostname, port, hint, wait: wait)    # Work is a promise object
            if wait
                dns.results
            else
                dns.then &block if block_given?
                dns
            end
        end

        # Get a new FSEvent instance
        #
        # @param path [String] the path to the file or folder for watching
        # @return [::MTLibuv::FSEvent]
        # @raise [ArgumentError] if path is not a string
        def fs_event(path)
            assert_type(String, path)
            FSEvent.new(@reactor, path)
        end

        # Opens a file and returns an object that can be used to manipulate it
        #
        # @param path [String] the path to the file or folder for watching
        # @param flags [Integer] see ruby File::Constants
        # @param mode [Integer]
        # @return [::MTLibuv::File]
        def file(path, flags = 0, mode: 0, **opts, &blk)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, flags, "flags must be an Integer")
            assert_type(Integer, mode, "mode must be an Integer")
            File.new(@reactor, path, flags, mode: mode, **opts, &blk)
        end

        # Returns an object for manipulating the filesystem
        #
        # @return [::MTLibuv::Filesystem]
        def filesystem
            Filesystem.new(@reactor)
        end

        def spawn(cmd, **args)
            Spawn.new(@reactor, cmd, **args)
        end

        # Schedule some work to be processed on the event reactor as soon as possible (thread safe)
        #
        # @yield the callback to be called on the reactor thread
        def schedule(&block)
            if reactor_thread?
                yield
            else
                @run_queue << block
                @process_queue.call
            end
            self
        end

        # Queue some work to be processed in the next iteration of the event reactor (thread safe)
        #
        # @param callback [Proc] the callback to be called on the reactor thread
        def next_tick(&block)
            @run_queue << block
            if reactor_thread?
                # Create a next tick timer
                if not @next_tick_scheduled
                    @next_tick.start(0)
                    @next_tick_scheduled = true
                    @next_tick.ref
                end
            else
                @process_queue.call
            end

            self
        end

        # Notifies the reactor there was an event that should be logged
        #
        # @param error [Exception] the error
        # @param msg [String|nil] optional context on the error
        # @param trace [Array<String>] optional additional trace of caller if async
        def log(error, msg = nil, trace = nil)
            @reactor_notify.call(error, msg, trace)
        end

        # Closes handles opened by the reactor class and completes the current reactor iteration (thread safe)
        def stop
            return unless @reactor_running
            @stop_reactor.call
        end

        # True if the calling thread is the same thread as the reactor.
        #
        # @return [Boolean]
        def reactor_thread?
            self == Thread.current.thread_variable_get(:reactor)
        end

        # Tells you whether the MTLibuv reactor reactor is currently running.
        #
        # @return [Boolean]
        def reactor_running?
            @reactor_running
        end
        alias_method :running?, :reactor_running?
    end
end
