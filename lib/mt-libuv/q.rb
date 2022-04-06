# frozen_string_literal: true

module MTLibuv
    module Q

        # @abstract
        class Promise
            private_class_method :new

            # This allows subclasses to make use of the catch feature
            alias_method :ruby_catch, :catch

            # Allows a backtrace to be included in any errors
            attr_accessor :trace

            #
            # regardless of when the promise was or will be resolved / rejected, calls
            # the error callback asynchronously if the promise is rejected.
            #
            # @param [Proc, &blk] callbacks error, error_block
            # @return [Promise] Returns an unresolved promise for chaining
            def catch(&blk)
                self.then(nil, blk)
            end


            def progress(&blk)
                self.then(nil, nil, blk)
            end

            # A future that provides the value or raises an error if a rejection occurs
            def value
                ::MTLibuv.co(self)
            end

            #
            # allows you to observe either the fulfillment or rejection of a promise, but to do so
            # without modifying the final value. This is useful to release resources or do some
            # clean-up that needs to be done whether the promise was rejected or resolved.
            #
            # @param [Proc, &blk] callbacks finally, finally_block
            # @return [Promise] Returns an unresolved promise for chaining
            def finally
                handleCallback = lambda { |value, isResolved|
                    callbackOutput = nil
                    begin
                        callbackOutput = yield
                    rescue Exception => e
                        @reactor.log e, 'performing promise finally callback', @trace
                        return make_promise(e, false, @reactor)
                    end

                    if callbackOutput.is_a?(Promise)
                        return callbackOutput.then(proc {
                                make_promise(value, isResolved, @reactor)
                            }, proc { |err|
                                make_promise(err, false, @reactor)
                            })
                    else
                        return make_promise(value, isResolved, @reactor)
                    end
                }

                self.then(proc {|val|
                    handleCallback.call(val, true)
                }, proc{|err|
                    handleCallback.call(err, false)
                })
            end

            protected

            def make_promise(value, resolved, reactor)
                result = Q.defer(reactor)
                if (resolved)
                    result.resolve(value)
                else
                    result.reject(value)
                end
                result.promise
            end
        end
        
        
        #
        # A new promise instance is created when a deferred instance is created and can be
        # retrieved by calling deferred.promise
        #
        class DeferredPromise < Promise
            public_class_method :new
            
            def initialize(reactor, defer)
                raise ArgumentError unless defer.is_a?(Deferred)
                super()

                @reactor = reactor
                @defer = defer
            end
            
            #
            # regardless of when the promise was or will be resolved / rejected, calls one of
            # the success or error callbacks asynchronously as soon as the result is available.
            # The callbacks are called with a single argument, the result or rejection reason.
            #
            # @param [Proc, Proc, Proc, &blk] callbacks error, success, progress, success_block
            # @return [Promise] Returns an unresolved promise for chaining
            def then(callback = nil, errback = nil, progback = nil, &block)
                result = Q.defer(@reactor)
                callback = block if block_given?
                
                wrappedCallback = proc { |val|
                    begin
                        result.resolve(callback ? callback.call(val) : val)
                    rescue Exception => e
                        result.reject(e)
                        @reactor.log e, 'performing promise resolution callback', @trace
                    end
                }
                
                wrappedErrback = proc { |reason|
                    begin
                        result.resolve(errback ? errback.call(reason) : Q.reject(@reactor, reason))
                    rescue Exception => e
                        result.reject(e)
                        @reactor.log e, 'performing promise rejection callback', @trace
                    end
                }

                wrappedProgback = proc { |*progress|
                    begin
                        result.notify(progback ? progback.call(*progress) : progress)
                    rescue Exception => e
                        @reactor.log e, 'performing promise progress callback', @trace
                    end
                }
                
                #
                # Schedule as we are touching shared state
                #    Everything else is locally scoped
                #
                @reactor.schedule do
                    pending_array = pending
                    
                    if pending_array.nil?
                        reference.then(wrappedCallback, wrappedErrback, wrappedProgback)
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
                @defer.pending
            end
            
            def reference
                @defer.reference
            end
        end



        class ResolvedPromise < Promise
            public_class_method :new

            def initialize(reactor, response, error = false)
                raise ArgumentError if error && response.is_a?(Promise)
                super()

                @reactor = reactor
                @error = error
                @response = response
            end

            def then(callback = nil, errback = nil, progback = nil, &block)
                result = Q.defer(@reactor)
                callback = block if block_given?

                @reactor.next_tick {
                    if @error
                        begin
                            result.resolve(errback ? errback.call(@response) : Q.reject(@reactor, @response))
                        rescue Exception => e
                            result.reject(e)
                            @reactor.log e, 'performing promise rejection callback', @trace
                        end
                    else
                        begin
                            result.resolve(callback ? callback.call(@response) : @response)
                        rescue Exception => e
                            result.reject(e)
                            @reactor.log e, 'performing promise resolution callback', @trace
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

            def initialize(reactor)
                super()

                @pending = []
                @reference = nil
                @reactor = reactor
            end

            attr_reader :pending, :reference

            #
            # resolves the derived promise with the value. If the value is a rejection constructed via
            # Q.reject, the promise will be rejected instead.
            #
            # @param [Object] val constant, message or an object representing the result.
            def resolve(val = nil)
                @reactor.schedule do
                    if not @pending.nil?
                        callbacks = @pending
                        @pending = nil
                        @reference = ref(@reactor, val)
                        
                        if callbacks.length > 0
                            callbacks.each do |callback|
                                @reference.then(callback[0], callback[1], callback[2])
                            end
                        end
                    end
                end
                self
            end

            #
            # rejects the derived promise with the reason. This is equivalent to resolving it with a rejection
            # constructed via Q.reject.
            #
            # @param [Object] reason constant, message, exception or an object representing the rejection reason.
            def reject(reason = nil)
                resolve(Q.reject(@reactor, reason))
            end

            #
            # Creates a promise object associated with this deferred
            #
            def promise
                @promise ||= DeferredPromise.new(@reactor, self)
                @promise # Should only ever be one per deferred
            end

            #
            # Provides an asynchronous callback mechanism
            #
            # @param [*Object] data you would like to send down the promise chain.
            def notify(*args)
                @reactor.schedule do     # just in case we are on a different event reactor
                    if @pending && @pending.length > 0
                        callbacks = @pending
                        @reactor.next_tick do
                            callbacks.each do |callback|
                                callback[2].call(*args)
                            end
                        end
                    end
                end
                self
            end

            def resolved?
                @pending.nil?
            end

            def value
                ::MTLibuv.co(self.promise)
            end

            # Overwrite to prevent inspecting errors hanging the VM
            def inspect
                if @pending.nil?
                    "#<#{self.class}:0x#{self.__id__.to_s(16)} @reactor=#{@reactor.inspect} @reference=#{@reference.inspect}>"
                else
					"#<#{self.class}:0x#{self.__id__.to_s(16)} @reactor=#{@reactor.inspect} @pending.count=#{@pending.length}>"
                end
            end
        end






        #
        # Creates a Deferred object which represents a task which will finish in the future.
        #
        # @return [Deferred] Returns a new instance of Deferred
        def defer(reactor)
            return Deferred.new(reactor)
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
        #     return Q.reject(reactor, reason)
        #   }, lambda {|result|
        #     # success: do something and resolve promiseB with the old or a new result
        #     return result
        #   })
        #
        # @param [Object] reason constant, message, exception or an object representing the rejection reason.
        # @return [Promise] Returns a promise that was already resolved as rejected with the reason
        def reject(reactor, reason = nil)
            return ResolvedPromise.new(reactor, reason, true)    # A resolved failed promise
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
        def all(reactor, *promises)
            deferred = Q.defer(reactor)
            promises = promises.flatten
            counter = promises.length
            results = []

            if counter > 0
                promises.each_index do |index|
                    ref(reactor, promises[index]).then(proc {|result|
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
                        Q.reject(@reactor, reason)    # Don't modify result
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
        def any(reactor, *promises)
            deferred = Q.defer(reactor)
            promises = promises.flatten
            if promises.length > 0
                promises.each_index do |index|
                    ref(reactor, promises[index]).then(proc { |result|
                        deferred.resolve(result)
                    }, proc { |reason|
                        deferred.reject(reason)
                        Q.reject(@reactor, reason)    # Don't modify result
                    })
                end
            else
                deferred.resolve(true)
            end
            deferred.promise
        end


        #
        # Combines multiple promises into a single promise that is resolved when all of the input
        # promises are resolved or rejected.
        #
        # @param [*Promise] Promises a number of promises that will be combined into a single promise
        # @return [Promise] Returns a single promise that will be resolved with an array of values,
        #   each [result, wasResolved] value pair corresponding to a at the same index in the `promises` array.
        def self.finally(reactor, *promises)
            deferred = Q.defer(reactor)
            promises = promises.flatten
            counter = promises.length
            results = []

            if counter > 0
                promises.each_index do |index|
                    ref(reactor, promises[index]).then(proc {|result|
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
                        Q.reject(@reactor, reason)    # Don't modify result
                    })
                end
            else
                deferred.resolve(results)
            end

            return deferred.promise
        end


        private


        def ref(reactor, value)
            return value if value.is_a?(Promise)
            return ResolvedPromise.new(reactor, value)            # A resolved success promise
        end


        module_function :all, :reject, :defer, :ref, :any
        private_class_method :ref
    end

end
