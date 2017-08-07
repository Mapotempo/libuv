# frozen_string_literal: true

module Libuv; end

# Use of a Fiber Pool increases performance as stack allocations
# don't need to continually occur. Especially useful on JRuby and
# Rubinius where multiple kernel threads and locks emulate Fibers.
class Libuv::FiberPool
    def initialize(thread)
        @reactor = thread
        reset
    end

    def exec
        if @reactor.reactor_thread?
            # Execute the block in a Fiber
            next_fiber do
                begin
                    yield
                rescue Exception => e
                    @on_error.call(e) if @on_error
                end
            end
        else
            # move the block onto the reactor thread
            @reactor.schedule do
                exec do
                    yield
                end
            end
        end
    end

    def on_error(&block)
        @on_error = block
    end

    def available
        @pool.size
    end

    def size
        @count
    end

    def reset
        @pool = []
        @count = 0
    end


    protected


    def next_fiber(&block)
        fib = if @pool.empty?
            new_fiber
        else
            @pool.pop
        end

        @job = block
        fib.resume
    end

    # Fibers are never cleaned up which shouldn't be much of an issue
    # This might lead to issues on Rubinius or JRuby however it should
    # generally improve performance on these platforms
    def new_fiber
        @count += 1

        Fiber.new do
            loop do
                job = @job
                @job = nil
                job.call

                @pool << Fiber.current
                Fiber.yield
            end
        end
    end
end
