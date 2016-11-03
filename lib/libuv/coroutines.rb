# frozen_string_literal: true

require 'fiber'

class CoroutineRejection < RuntimeError
    attr_accessor :value
end

class Object
    private


    # Takes a Promise response and turns it into a co-routine
    # for code execution without using callbacks
    #
    # @param *promises [::Libuv::Q::Promise] a number of promises that will be combined into a single promise
    # @return [Object] Returns the result of a single promise or an array of results if provided multiple promises
    # @raise [Exception] if the promise is rejected
    def co(*yieldable, &block)
        on_reactor = Libuv::Reactor.current
        raise 'must be running on a reactor thread to use coroutines' unless on_reactor

        f = Fiber.current
        wasError = false

        # Convert the input into a promise on the current reactor
        if yieldable.length == 1
            promise = yieldable[0]
            # Passed independently as this is often overwritten for performance
            promise.progress(block) if block_given?
        else
            promise = on_reactor.all(*yieldable)
        end

        # Use the promise to resume the Fiber
        promise.then(proc { |res|
            if Libuv::Reactor.current == on_reactor
                f.resume res
            else
                on_reactor.schedule { f.resume(res) }
            end
        }, proc { |err|
            wasError = true
            if Libuv::Reactor.current == on_reactor
                f.resume err
            else
                on_reactor.schedule { f.resume(err) }
            end
        })

        # We want to prevent the reactor from stopping while we are waiting on a response
        on_reactor.ref
        result = Fiber.yield # Assign the result from the resume
        on_reactor.unref

        # Either return the result or raise an error
        if wasError
            if result.is_a?(Exception)
                backtrace = caller
                if result.respond_to?(:backtrace) && result.backtrace
                    backtrace << '---- continuation ----'
                    backtrace.concat(result.backtrace)
                end
                result.set_backtrace(backtrace)
                raise result
            else
                e = case result
                when String, Symbol
                    CoroutineRejection.new(result.to_s)
                else
                    CoroutineRejection.new
                end
                e.value = result
                raise e
            end
        end
        result
    end
end
