require 'thread'

module Libuv
    class Loop
        include Resource, Assertions


        LOOPS = ThreadSafe::Cache.new
        CRITICAL = Mutex.new
        @@use_fibers = false


        module ClassMethods
            # Get default loop
            # 
            # @return [::Libuv::Loop]
            def default
                return @default unless @default.nil?
                CRITICAL.synchronize {
                    return @default ||= create(::Libuv::Ext.default_loop)
                }
            end

            # Create new Libuv loop
            # 
            # @return [::Libuv::Loop]
            def new
                return create(::Libuv::Ext.loop_new)
            end

            # Build a Ruby Libuv loop from an existing loop pointer
            # 
            # @return [::Libuv::Loop]
            def create(pointer)
                allocate.tap { |i| i.send(:initialize, FFI::AutoPointer.new(pointer, ::Libuv::Ext.method(:loop_delete))) }
            end

            # Checks for the existence of a loop on the current thread
            #
            # @return [::Libuv::Loop | nil]
            def current
                LOOPS[Thread.current]
            end
        end
        extend ClassMethods


        # Initialize a loop using an FFI::Pointer to a libuv loop
        def initialize(pointer) # :notnew:
            @pointer = pointer
            @loop = self

            # Create an async call for scheduling work from other threads
            @run_queue = Queue.new
            @process_queue = @loop.async method(:process_queue_cb)
            @process_queue.unref

            # Create a next tick timer
            @next_tick = @loop.timer method(:next_tick_cb)
            @next_tick.unref

            # Create an async call for ending the loop
            @stop_loop = @loop.async method(:stop_cb)
            @stop_loop.unref
        end


        protected


        def stop_cb
            LOOPS.delete(@reactor_thread)
            @reactor_thread = nil

            ::Libuv::Ext.stop(@pointer)
        end

        def next_tick_cb
            @next_tick_scheduled = false
            @next_tick.unref
            process_queue_cb
        end

        def process_queue_cb
            # ensure we only execute what was required for this tick
            length = @run_queue.length
            length.times do
                process_item
            end
        end

        def process_item
            begin
                run = @run_queue.pop true  # pop non-block
                run.call
            rescue Exception => e
                @loop.log :error, :next_tick_cb, e
            end
        end


        public


        # Overwrite as errors in jRuby can literally hang VM when inspecting
        # as many many classes will reference this class
        def inspect
            "#<#{self.class}:0x#{self.__id__.to_s(16)} NT=#{@run_queue.length}>"
        end


        def handle; @pointer; end

        # Run the actual event loop. This method will block until the loop is stopped.
        #
        # @param run_type [:UV_RUN_DEFAULT, :UV_RUN_ONCE, :UV_RUN_NOWAIT]
        # @yieldparam promise [::Libuv::Q::Promise] Yields a promise that can be used for logging unhandled
        #   exceptions on the loop.
        def run(run_type = :UV_RUN_DEFAULT)
            if @reactor_thread.nil?
                @loop_notify = @loop.defer

                begin
                    @reactor_thread = Thread.current
                    LOOPS[@reactor_thread] = @loop
                    if block_given?
                        if @@use_fibers
                            Fiber.new { yield @loop_notify.promise }.resume
                        else
                            yield @loop_notify.promise
                        end
                    end
                    ::Libuv::Ext.run(@pointer, run_type)  # This is blocking
                ensure
                    @reactor_thread = nil
                    @run_queue.clear
                end
            elsif block_given?
                if @@use_fibers
                    schedule { Fiber.new { yield @loop_notify.promise }.resume }
                else
                    schedule { yield @loop_notify.promise }
                end
            end
            @loop
        end


        # Provides a promise notifier for receiving un-handled exceptions
        #
        # @return [::Libuv::Q::Promise]
        def notifier
            @loop_notify.promise
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
        # @param *promises [::Libuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::Libuv::Q::Promise] Returns a single promise that will be resolved with an array of values,
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
        # @param *promises [::Libuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::Libuv::Q::Promise] Returns a single promise
        def any(*promises)
            Q.any(@loop, *promises)
        end

        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved or rejected.
        #
        # @param *promises [::Libuv::Q::Promise] a number of promises that will be combined into a single promise
        # @return [::Libuv::Q::Promise] Returns a single promise that will be resolved with an array of values,
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

        # Get current time in milliseconds
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

            if name
                msg  = ::Libuv::Ext.strerror(err)
                ::Libuv::Error.const_get(name.to_sym).new(msg)
            else
                # We want a back-trace in this case
                raise "error lookup failed for code #{err}"
            end
        rescue Exception => e
            @loop.log :warn, :error_lookup_failed, e
            e
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
        # @param ipc [true, false] indicate if a handle will be used for ipc, useful for sharing tcp socket between processes
        # @return [::Libuv::Pipe]
        def pipe(ipc = false)
            Pipe.new(@loop, ipc)
        end

        # Get a new timer instance
        # 
        # @param callback [Proc] the callback to be called on timer trigger
        # @return [::Libuv::Timer]
        def timer(callback = nil, &blk)
            Timer.new(@loop, callback || blk)
        end

        # Get a new Prepare handle
        # 
        # @return [::Libuv::Prepare]
        def prepare(callback = nil, &blk)
            Prepare.new(@loop, callback || blk)
        end

        # Get a new Check handle
        # 
        # @return [::Libuv::Check]
        def check(callback = nil, &blk)
            Check.new(@loop, callback || blk)
        end

        # Get a new Idle handle
        # 
        # @param callback [Proc] the callback to be called on idle trigger
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

        # Get a new signal handler
        # 
        # @return [::Libuv::Signal]
        def signal(signum = nil, callback = nil, &block)
            callback ||= block
            handle = Signal.new(@loop)
            handle.progress callback if callback
            handle.start(signum) if signum
            handle
        end

        # Queue some work for processing in the libuv thread pool
        #
        # @param callback [Proc] the callback to be called in the thread pool
        # @return [::Libuv::Work]
        # @raise [ArgumentError] if block is not given
        def work(callback = nil, &block)
            callback ||= block
            assert_block(callback)
            Work.new(@loop, callback)    # Work is a promise object
        end

        # Lookup a hostname
        #
        # @param hostname [String] the domain name to lookup
        # @param port [Integer, String] the service being connected too
        # @param callback [Proc] the callback to be called on success
        # @return [::Libuv::Dns]
        def lookup(hostname, hint = :IPv4, port = 9, &block)
            dns = Dns.new(@loop, hostname, port, hint)    # Work is a promise object
            dns.then block if block_given?
            dns
        end

        # Get a new FSEvent instance
        # 
        # @param path [String] the path to the file or folder for watching
        # @return [::Libuv::FSEvent]
        # @raise [ArgumentError] if path is not a string
        def fs_event(path)
            assert_type(String, path)
            FSEvent.new(@loop, path)
        end

        # Opens a file and returns an object that can be used to manipulate it
        #
        # @param path [String] the path to the file or folder for watching
        # @param flags [Integer] see ruby File::Constants
        # @param mode [Integer]
        # @return [::Libuv::File]
        def file(path, flags = 0, mode = 0)
            assert_type(String, path, "path must be a String")
            assert_type(Integer, flags, "flags must be an Integer")
            assert_type(Integer, mode, "mode must be an Integer")
            File.new(@loop, path, flags, mode)
        end

        # Returns an object for manipulating the filesystem
        #
        # @return [::Libuv::Filesystem]
        def filesystem
            Filesystem.new(@loop)
        end

        # Schedule some work to be processed on the event loop as soon as possible (thread safe)
        #
        # @param callback [Proc] the callback to be called on the reactor thread
        # @raise [ArgumentError] if block is not given
        def schedule(callback = nil, &block)
            callback ||= block
            assert_block(callback)

            if reactor_thread?
                callback.call
            else
                @run_queue << callback
                @process_queue.call
            end
        end

        # Queue some work to be processed in the next iteration of the event loop (thread safe)
        #
        # @param callback [Proc] the callback to be called on the reactor thread
        # @raise [ArgumentError] if block is not given
        def next_tick(callback = nil, &block)
            callback ||= block
            assert_block(callback)

            @run_queue << callback
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
        end

        # Notifies the loop there was an event that should be logged
        #
        # @param level [Symbol] the error level (info, warn, error etc)
        # @param id [Object] some kind of identifying information
        # @param *args [*args] any additional information
        def log(level, id, *args)
            @loop_notify.notify(level, id, *args)
        end

        # Closes handles opened by the loop class and completes the current loop iteration (thread safe)
        def stop
            @stop_loop.call
        end

        # True if the calling thread is the same thread as the reactor.
        #
        # @return [Boolean]
        def reactor_thread?
            @reactor_thread == Thread.current
        end

        # Exposed to allow joining on the thread, when run in a multithreaded environment. Performing other actions on the thread has undefined semantics (read: a dangerous endevor).
        #
        # @return [Thread]
        def reactor_thread
            @reactor_thread
        end

        # Tells you whether the Libuv reactor loop is currently running.
        #
        # @return [Boolean]
        def reactor_running?
            !@reactor_thread.nil?
        end
    end
end
