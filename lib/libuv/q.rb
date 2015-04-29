
module Libuv
    module Q

        # @abstract
        class Promise
            private_class_method :new


            # Used by finally method
            MAKE_PROMISE = proc { |value, resolved, loop|
                result = Q.defer(loop)
                if (resolved)
                    result.resolve(value)
                else
                    result.reject(value)
                end
                result.promise
            }.freeze


            #
            # regardless of when the promise was or will be resolved / rejected, calls
            # the error callback asynchronously if the promise is rejected.
            #
            # @param [Proc, &blk] callbacks error, error_block
            # @return [Promise] Returns an unresolved promise for chaining
            def catch(callback = nil, &blk)
                self.then(nil, callback || blk)
            end


            def progress(callback = nil, &blk)
                self.then(nil, nil, callback || blk)
            end


            #
            # allows you to observe either the fulfillment or rejection of a promise, but to do so
            # without modifying the final value. This is useful to release resources or do some
            # clean-up that needs to be done whether the promise was rejected or resolved.
            #
            # @param [Proc, &blk] callbacks finally, finally_block
            # @return [Promise] Returns an unresolved promise for chaining
            def finally(callback = nil, &blk)
                callback ||= blk

                handleCallback = lambda {|value, isResolved|
                    callbackOutput = nil
                    begin
                        callbackOutput = callback.call
                    rescue Exception => e
                        @loop.log(:error, :q_finally_cb, e)
                        return MAKE_PROMISE.call(e, false, @loop)
                    end

                    if callbackOutput.is_a?(Promise)
                        return callbackOutput.then(proc {
                                MAKE_PROMISE.call(value, isResolved, @loop)
                            }, proc { |err|
                                MAKE_PROMISE.call(err, false, @loop)
                            })
                    else
                        return MAKE_PROMISE.call(value, isResolved, @loop)
                    end
                }

                self.then(proc {|val|
                    handleCallback.call(val, true)
                }, proc{|err|
                    handleCallback.call(err, false)
                })
            end
        end
        
        
        #
        # A new promise instance is created when a deferred instance is created and can be
        # retrieved by calling deferred.promise
        #
        class DeferredPromise < Promise
            public_class_method :new
            
            def initialize(loop, defer)
                raise ArgumentError unless defer.is_a?(Deferred)
                super()
                
                @loop = loop
                @defer = defer
            end
            
            #
            # regardless of when the promise was or will be resolved / rejected, calls one of
            # the success or error callbacks asynchronously as soon as the result is available.
            # The callbacks are called with a single argument, the result or rejection reason.
            #
            # @param [Proc, Proc, Proc, &blk] callbacks error, success, progress, success_block
            # @return [Promise] Returns an unresolved promise for chaining
            def then(callback = nil, errback = nil, progback = nil, &blk)
                result = Q.defer(@loop)
                
                callback ||= blk
                
                wrappedCallback = proc { |val|
                    begin
                        result.resolve(callback.nil? ? val : callback.call(val))
                    rescue Exception => e
                        #warn "\nUnhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
                        result.reject(e)
                        @loop.log(:error, :q_resolve_cb, e)
                    end
                }
                
                wrappedErrback = proc { |reason|
                    begin
                        result.resolve(errback.nil? ? Q.reject(@loop, reason) : errback.call(reason))
                    rescue Exception => e
                        #warn "Unhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
                        result.reject(e)
                        @loop.log(:error, :q_reject_cb, e)
                    end
                }

                wrappedProgback = proc { |*progress|
                    begin
                        result.notify(progback.nil? ? progress : progback.call(*progress))
                    rescue Exception => e
                        #warn "Unhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
                        @loop.log(:error, :q_progress_cb, e)
                    end
                }
                
                #
                # Schedule as we are touching shared state
                #    Everything else is locally scoped
                #
                @loop.schedule do
                    pending_array = pending
                    
                    if pending_array.nil?
                        value.then(wrappedCallback, wrappedErrback, wrappedProgback)
                    else
                        pending_array << [wrappedCallback, wrappedErrback, wrappedProgback]
                    end
                end
                
                result.promise
            end

            def resolved?
                pending.nil?
            end
            
            
            private
            
            
            def pending
                @defer.instance_eval { @pending }
            end
            
            def value
                @defer.instance_eval { @value }
            end
        end
        
        
        
        class ResolvedPromise < Promise
            public_class_method :new
            
            def initialize(loop, response, error = false)
                raise ArgumentError if error && response.is_a?(Promise)
                super()
                
                @loop = loop
                @error = error
                @response = response
            end
            
            def then(callback = nil, errback = nil, progback = nil, &blk)
                result = Q.defer(@loop)
                
                callback ||= blk
                
                @loop.next_tick {
                    if @error
                        begin
                            result.resolve(errback.nil? ? Q.reject(@loop, @response) : errback.call(@response))
                        rescue Exception => e
                            #warn "Unhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
                            result.reject(e)
                            @loop.log(:error, :q_reject_cb, e)
                        end
                    else
                        begin
                            result.resolve(callback.nil? ? @response : callback.call(@response))
                        rescue Exception => e
                            #warn "\nUnhandled exception: #{e.message}\n#{e.backtrace.join("\n")}\n"
                            result.reject(e)
                            @loop.log(:error, :q_resolve_cb, e)
                        end
                    end
                }
                
                result.promise
            end

            def resolved?
                true
            end
        end
        
        
        #
        # The purpose of the deferred object is to expose the associated Promise instance as well
        # as APIs that can be used for signalling the successful or unsuccessful completion of a task.
        #
        class Deferred
            include Q
            
            def initialize(loop)
                super()
                
                @pending = []
                @value = nil
                @loop = loop
            end
            
            #
            # resolves the derived promise with the value. If the value is a rejection constructed via
            # Q.reject, the promise will be rejected instead.
            #
            # @param [Object] val constant, message or an object representing the result.
            def resolve(val = nil)
                @loop.schedule do
                    if not @pending.nil?
                        callbacks = @pending
                        @pending = nil
                        @value = ref(@loop, val)
                        
                        if callbacks.length > 0
                            callbacks.each do |callback|
                                @value.then(callback[0], callback[1], callback[2])
                            end
                        end
                    end
                end
            end
            
            #
            # rejects the derived promise with the reason. This is equivalent to resolving it with a rejection
            # constructed via Q.reject.
            #
            # @param [Object] reason constant, message, exception or an object representing the rejection reason.
            def reject(reason = nil)
                resolve(Q.reject(@loop, reason))
            end
            
            #
            # Creates a promise object associated with this deferred
            #
            def promise
                @promise ||= DeferredPromise.new(@loop, self)
                @promise # Should only ever be one per deferred
            end

            #
            # Provides an asynchronous callback mechanism
            #
            # @param [*Object] data you would like to send down the promise chain.
            def notify(*args)
                @loop.schedule do     # just in case we are on a different event loop
                    if @pending && @pending.length > 0
                        callbacks = @pending
                        @loop.next_tick do
                            callbacks.each do |callback|
                                callback[2].call(*args)
                            end
                        end
                    end
                end
            end

            def resolved?
                @pending.nil?
            end

            # Overwrite to prevent inspecting errors hanging the VM
            def inspect
                if @pending.nil?
                    "#<#{self.class}:0x#{self.__id__.to_s(16)} @loop=#{@loop.inspect} @value=#{@value.inspect}>"
                else
					"#<#{self.class}:0x#{self.__id__.to_s(16)} @loop=#{@loop.inspect} @pending.count=#{@pending.length}>"
                end
            end
        end
        
        
        
        
        
        
        #
        # Creates a Deferred object which represents a task which will finish in the future.
        #
        # @return [Deferred] Returns a new instance of Deferred
        def defer(loop)
            return Deferred.new(loop)
        end
        
        
        #
        # Creates a promise that is resolved as rejected with the specified reason. This api should be
        # used to forward rejection in a chain of promises. If you are dealing with the last promise in
        # a promise chain, you don't need to worry about it.
        #
        # When comparing deferreds/promises to the familiar behaviour of try/catch/throw, think of
        # reject as the raise keyword in Ruby. This also means that if you "catch" an error via
        # a promise error callback and you want to forward the error to the promise derived from the
        # current promise, you have to "rethrow" the error by returning a rejection constructed via
        # reject.
        #
        # @example handling rejections
        #
        #   #!/usr/bin/env ruby
        #
        #   require 'rubygems' # or use Bundler.setup
        #   require 'em-promise'
        #
        #   promiseB = promiseA.then(lambda {|reason|
        #     # error: handle the error if possible and resolve promiseB with newPromiseOrValue,
        #     #        otherwise forward the rejection to promiseB
        #     if canHandle(reason)
        #       # handle the error and recover
        #       return newPromiseOrValue
        #     end
        #     return Q.reject(loop, reason)
        #   }, lambda {|result|
        #     # success: do something and resolve promiseB with the old or a new result
        #     return result
        #   })
        #
        # @param [Object] reason constant, message, exception or an object representing the rejection reason.
        # @return [Promise] Returns a promise that was already resolved as rejected with the reason
        def reject(loop, reason = nil)
            return ResolvedPromise.new(loop, reason, true)    # A resolved failed promise
        end
        
        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise that will be resolved with an array of values,
        #   each value corresponding to the promise at the same index in the `promises` array. If any of
        #   the promises is resolved with a rejection, this resulting promise will be resolved with the
        #   same rejection.
        def all(loop, *promises)
            deferred = Q.defer(loop)
            counter = promises.length
            results = []
            
            if counter > 0
                promises.each_index do |index|
                    ref(loop, promises[index]).then(proc {|result|
                        if results[index].nil?
                            results[index] = result
                            counter -= 1
                            deferred.resolve(results) if counter <= 0
                        end
                        result
                    }, proc {|reason|
                        if results[index].nil?
                            deferred.reject(reason)
                        end
                        Q.reject(@loop, reason)    # Don't modify result
                    })
                end
            else
                deferred.resolve(results)
            end
            
            return deferred.promise
        end


        #
        # Combines multiple promises into a single promise that is resolved when any of the input
        # promises are resolved.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise
        def any(loop, *promises)
            deferred = Q.defer(loop)
            if promises.length > 0
                promises.each_index do |index|
                    ref(loop, promises[index]).then(proc {|result|
                        deferred.resolve(true)
                        result
                    }, proc {|reason|
                        deferred.reject(false)
                        Q.reject(@loop, reason)    # Don't modify result
                    })
                end
            else
                deferred.resolve(true)
            end
        end


        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved or rejected.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise that will be resolved with an array of values,
        #   each [result, wasResolved] value pair corresponding to a at the same index in the `promises` array.
        def self.finally(loop, *promises)
            deferred = Q.defer(loop)
            counter = promises.length
            results = []
            
            if counter > 0
                promises.each_index do |index|
                    ref(loop, promises[index]).then(proc {|result|
                        if results[index].nil?
                            results[index] = [result, true]
                            counter -= 1
                            deferred.resolve(results) if counter <= 0
                        end
                        result
                    }, proc {|reason|
                        if results[index].nil?
                            results[index] = [reason, false]
                            counter -= 1
                            deferred.resolve(results) if counter <= 0
                        end
                        Q.reject(@loop, reason)    # Don't modify result
                    })
                end
            else
                deferred.resolve(results)
            end
            
            return deferred.promise
        end
        
        
        private
        
        
        def ref(loop, value)
            return value if value.is_a?(Promise)
            return ResolvedPromise.new(loop, value)            # A resolved success promise
        end
        
        
        module_function :all, :reject, :defer, :ref, :any
        private_class_method :ref
    end

end
