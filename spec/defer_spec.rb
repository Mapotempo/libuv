require 'mt-libuv'


describe MTLibuv::Q do
    
    before :each do
        @reactor = MTLibuv::Reactor.default
        @reactor.notifier {}
        @deferred = @reactor.defer
        @promise = @deferred.promise
        @log = []
        @default_fail = proc { |reason|
            @reactor.stop
        }
    end

    after :each do
        @reactor.notifier
    end
    
    
    describe 'resolve' do
        
        
        it "should call the callback in the next turn" do
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << result
                end
                
                @deferred.resolve(:foo)
            }

            expect(@log).to eq([:foo])
        end
        
        
        
        it "should be able to resolve the callback after it has already been resolved" do
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << result
                    @promise.then nil, @default_fail do |result|
                        @log << result
                    end
                end
                
                @deferred.resolve(:foo)
            }
            expect(@log).to eq([:foo, :foo])
        end
        
        
        
        it "should fulfill success callbacks in the registration order" do
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << :first
                end
                
                @promise.then nil, @default_fail do |result|
                    @log << :second
                end
                
                @deferred.resolve(:foo)
            }
            expect(@log).to eq([:first, :second])
        end
        
        
        it "should do nothing if a promise was previously resolved" do
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << result
                    expect(@log).to eq([:foo])
                    @deferred.resolve(:bar)
                end
                
                @deferred.resolve(:foo)
                @deferred.reject(:baz)
            }
            expect(@log).to eq([:foo])
        end
        
        
        it "should allow deferred resolution with a new promise" do
            deferred2 = @reactor.defer
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << result
                    @reactor.stop
                end
                
                @deferred.resolve(deferred2.promise)
                deferred2.resolve(:foo)
            }
            expect(@log).to eq([:foo])
        end
        
        
        it "should not break if a callbacks registers another callback" do
            @reactor.run {
                @promise.then nil, @default_fail do |result|
                    @log << :outer
                    @promise.then nil, @default_fail do |result|
                        @log << :inner
                    end
                end
                
                @deferred.resolve(:foo)
            }

            expect(@log).to eq([:outer, :inner])
        end
        
        
        
        it "can modify the result of a promise before returning" do
            @reactor.run {
                proc { |name|
                    @reactor.work { @deferred.resolve("Hello #{name}") }
                    @promise.then nil, @default_fail do |result|
                        @log << result
                        result += "?"
                        result
                    end
                }.call('Robin Hood').then nil, @default_fail do |greeting|
                    @log << greeting
                    @reactor.stop
                end
            }

            expect(@log).to eq(['Hello Robin Hood', 'Hello Robin Hood?'])
        end
    
    end
    
    
    describe 'reject' do
    
        it "should reject the promise and execute all error callbacks" do
            @reactor.run {
                @promise.then(@default_fail, proc {|result|
                    @log << :first
                })
                @promise.then(@default_fail, proc {|result|
                    @log << :second
                })
                
                @deferred.reject(:foo)
            }
            expect(@log).to eq([:first, :second])
        end
        
        
        it "should do nothing if a promise was previously rejected" do
            @reactor.run {
                @promise.then(@default_fail, proc {|result|
                    @log << result
                    @deferred.resolve(:bar)
                })
                
                @deferred.reject(:baz)
                @deferred.resolve(:foo)
            }
            expect(@log).to eq([:baz])
        end
        
        
        it "should not defer rejection with a new promise" do
            deferred2 = @reactor.defer
            @reactor.run {
                @promise.then(@default_fail, @default_fail)
                begin
                    @deferred.reject(deferred2.promise)
                rescue => e
                    @log << e.is_a?(ArgumentError)
                    @reactor.stop
                end
            }

            expect(@log).to eq([true])
        end
        
    end


    describe 'notify' do
        it "should execute all progress callbacks in the registration order" do
            @reactor.run {
                @promise.progress do |update|
                    @log << :first
                end
                
                @promise.progress do |update|
                    @log << :second
                end
                
                @deferred.notify(:foo)
            }

            expect(@log).to eq([:first, :second])
        end

        it "should do nothing if a promise was previously resolved" do
            @reactor.run {

                @promise.progress do |update|
                    @log << update
                end

                @deferred.resolve(:foo)
                @deferred.notify(:baz)
            }

            expect(@log).to eq([])
        end

        it "should do nothing if a promise was previously rejected" do
            @reactor.run {

                @promise.progress do |update|
                    @log << update
                end
                @deferred.reject(:foo)
                @deferred.notify(:baz)
            }

            expect(@log).to eq([])
        end


        it "should not apply any special treatment to promises passed to notify" do
            @reactor.run {
                deferred2 = @reactor.defer

                @promise.progress do |update|
                    @log << update.is_a?(::MTLibuv::Q::Promise)
                end
                @deferred.notify(deferred2.promise)
            }

            expect(@log).to eq([true])
        end


        it "should call the progress callbacks in the next turn" do
            @reactor.run {
                @promise.progress do |update|
                    @log << :first
                end
                
                @promise.progress do |update|
                    @log << :second
                end
                
                @deferred.notify(:foo)
                
                @log << @log.length    # Has notify run in this tick
            }

            expect(@log).to eq([0, :first, :second])
        end

        it "should ignore notifications sent out in the same turn before listener registration" do
            @reactor.run {
                @deferred.notify(:foo)

                @promise.progress do |update|
                    @log << :first
                end
                
                @promise.progress do |update|
                    @log << :second
                end
            }

            expect(@log).to eq([])
        end
    end
    
    
    describe MTLibuv::Q::Promise do

        describe 'then' do
            
            it "should allow registration of a success callback without an errback and resolve" do
                @reactor.run {
                    @promise.then do |result|
                        @log << result
                    end

                    @deferred.resolve(:foo)
                }

                expect(@log).to eq([:foo])
            end
            
            
            it "should allow registration of a success callback without an errback and reject" do
                @reactor.run {
                    @promise.then do |result|
                        @log << result
                    end

                    @deferred.reject(:foo)
                }

                expect(@log).to eq([])
            end
            
            
            it "should allow registration of an errback without a success callback and reject" do
                @reactor.run {
                    @promise.catch { |reason|
                        @log << reason
                    }

                    @deferred.reject(:foo)
                }

                expect(@log).to eq([:foo])
            end
            
            
            it "should allow registration of an errback without a success callback and resolve" do
                @reactor.run {
                    @promise.catch { |reason|
                        @log << reason
                    }

                    @deferred.resolve(:foo)
                }

                expect(@log).to eq([])
            end
            
            
            it "should resolve all callbacks with the original value" do
                @reactor.run {
                    @promise.then nil, @default_fail do |result|
                        @log << result
                        :alt1
                    end
                    @promise.then nil, @default_fail do |result|
                        @log << result
                        'ERROR'
                    end
                    @promise.then nil, @default_fail do |result|
                        @log << result
                        MTLibuv::Q.reject(@reactor, 'some reason')
                    end
                    @promise.then nil, @default_fail do |result|
                        @log << result
                        :alt2
                    end
                    
                    @deferred.resolve(:foo)
                }

                expect(@log).to eq([:foo, :foo, :foo, :foo])
            end


            it "should notify all callbacks with the original value" do
                @reactor.run { |reactor_promise|
                    @promise.progress do |result|
                        @log << result
                        :alt1
                    end
                    @promise.progress do |result|
                        @log << result
                        'ERROR'
                    end
                    @promise.progress do |result|
                        @log << result
                        MTLibuv::Q.reject(@reactor, 'some reason')
                    end
                    @promise.progress do |result|
                        @log << result
                        :alt2
                    end

                    
                    @deferred.notify(:foo)
                }

                expect(@log).to eq([:foo, :foo, :foo, :foo])
            end
            
            
            it "should reject all callbacks with the original reason" do
                @reactor.run {
                    @promise.then(@default_fail, proc {|result|
                        @log << result
                        :alt1
                    })
                    @promise.then(@default_fail, proc {|result|
                        @log << result
                        'ERROR'
                    })
                    @promise.then(@default_fail, proc {|result|
                        @log << result
                        MTLibuv::Q.reject(@reactor, 'some reason')
                    })
                    @promise.then(@default_fail, proc {|result|
                        @log << result
                        :alt2
                    })
                    
                    @deferred.reject(:foo)
                }

                expect(@log).to eq([:foo, :foo, :foo, :foo])
            end
            
            
            it "should propagate resolution and rejection between dependent promises" do
                @reactor.run {
                    @promise.then(proc { |result|
                        @log << result
                        :bar
                    }, @default_fail).then(proc { |result|
                        @log << result
                        raise 'baz'
                    }, @default_fail).then(@default_fail, proc {|result|
                        @log << result.message
                        raise 'bob'
                    }).then(@default_fail, proc {|result|
                        @log << result.message
                        :done
                    }).then(proc { |result|
                        @log << result
                    }, @default_fail)
                    
                    @deferred.resolve(:foo)
                }

                expect(@log).to eq([:foo, :bar, 'baz', 'bob', :done])
            end


            it "should propagate notification between dependent promises" do
                @reactor.run { |reactor|
                    reactor.notifier do |type, id, error|
                        @log << id
                    end


                    @promise.progress { |result|
                        @log << result
                        :bar
                    }.progress { |result|
                        @log << result
                        result
                    }.progress { |result|
                        @log << result
                        result
                    }.progress { |result|
                        @log << result
                        :done
                    }.progress { |result|
                        @log << result
                        result
                    }

                    
                    @deferred.notify(:foo)
                }

                expect(@log).to eq([:foo, :bar, :bar, :bar, :done])
            end


            it "should stop notification propagation in case of error" do
                @reactor.run { |reactor|
                    reactor.notifier do |error, context|
                        @log << context
                    end


                    @promise.progress { |result|
                        @log << result
                        :bar
                    }.progress { |result|
                        @log << result
                        raise 'err'
                        result
                    }.progress {|result|
                        @log << result
                        result
                    }.progress {|result|
                        @log << result
                        :done
                    }.progress { |result|
                        @log << result
                        result
                    }

                    
                    @deferred.notify(:foo)
                }

                expect(@log).to eq([:foo, :bar, "performing promise progress callback"])
            end
            
            
            it "should call error callback in the next turn even if promise is already rejected" do
                @reactor.run {
                    @deferred.reject(:foo)
                    
                    @promise.catch { |reason|
                        @log << reason
                    }
                    
                    @reactor.next_tick do
                        @reactor.stop
                    end
                }

                expect(@log).to eq([:foo])
            end
            
            
        end


        describe 'finally' do

            describe 'when the promise is fulfilled' do

                it "should call the callback" do
                    @reactor.run {
                        @promise.finally do
                            @log << :finally
                        end

                        @deferred.resolve(:foo)
                    }

                    expect(@log).to eq([:finally])
                end

                it "should fulfill with the original value" do
                    @reactor.run {
                        @promise.finally {
                            @log << :finally
                            :finally
                        }.then do |result|
                            @log << result
                        end
                        

                        @deferred.resolve(:foo)
                    }

                    expect(@log).to eq([:finally, :foo])
                end

                it "should fulfill with the original value (larger test)" do
                    @reactor.run {
                        @promise.then { |result|
                            @log << result
                            result
                        }.finally {
                            @log << :finally
                            :finally
                        }.then { |result|
                            @log << result
                            :change
                        }.then { |result|
                            @log << result
                            result
                        }.finally {
                            @log << :finally
                            :finally
                        }.then { |result|
                            @log << result
                            result
                        }
                        

                        @deferred.resolve(:foo)
                    }

                    expect(@log).to eq([:foo, :finally, :foo, :change, :finally, :change])
                end

                describe "when the callback throws an exception" do
                    it "should reject with this new exception" do
                        @reactor.run {
                            @promise.finally {
                                @log << :finally
                                raise 'error'
                            }.catch do |reason|
                                @log.push reason.is_a?(Exception)
                            end
                            
                            @deferred.resolve(:foo)
                        }

                        expect(@log).to eq([:finally, true])
                    end
                end

                describe "when the callback returns a promise" do
                    it "should fulfill with the original reason after that promise resolves" do
                        @reactor.run {
                            deferred2 = @reactor.defer

                            @promise.finally {
                                @log << :finally
                                deferred2.promise
                            }.then do |result|
                                @log << result
                            end
                            
                            @deferred.resolve(:foo)
                            
                            @reactor.next_tick do
                                @reactor.next_tick do
                                    @reactor.next_tick do
                                        @reactor.next_tick do
                                            @log << :resolving
                                            deferred2.resolve('working')
                                        end
                                    end
                                end
                            end
                        }

                        expect(@log).to eq([:finally, :resolving, :foo])
                    end


                    it "should reject with the new reason when it is rejected" do
                        @reactor.run {
                            deferred2 = @reactor.defer

                            @promise.finally {
                                @log << :finally
                                deferred2.promise
                            }.catch do |result|
                                @log << result
                            end
                            
                            @deferred.resolve(:foo)
                            
                            @reactor.next_tick do
                                @reactor.next_tick do
                                    @reactor.next_tick do
                                        @reactor.next_tick do
                                            @log << :rejecting
                                            deferred2.reject(:rejected)
                                        end
                                    end
                                end
                            end
                        }

                        expect(@log).to eq([:finally, :rejecting, :rejected])
                    end
                end

            end

        end


        describe 'value' do
            it "should resolve a promise value as a future" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.resolve(:foo)
                    end
                    @log << @deferred.promise.value
                }

                expect(@log).to eq([:foo])
            end

            it "should reject a promise value as a future" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.reject(:foo)
                    end

                    begin
                        @deferred.promise.value
                        @log << 'should raise exception'
                    rescue => e
                        expect(e.class).to eq(CoroutineRejection)
                        @log << e.value
                    end
                }

                expect(@log).to eq([:foo])
            end

            it "should resolve a deferred value as a future" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.resolve(:foo)
                    end
                    @log << @deferred.value
                }

                expect(@log).to eq([:foo])
            end

            it "should reject a deferred value as a future" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.reject(:foo)
                    end

                    begin
                        @deferred.value
                        @log << 'should raise exception'
                    rescue => e
                        expect(e.class).to eq(CoroutineRejection)
                        @log << e.value
                    end
                }

                expect(@log).to eq([:foo])
            end

            it "should reject with message when rejection was a string" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.reject('foo')
                    end

                    begin
                        @deferred.value
                        @log << 'should raise exception'
                    rescue => e
                        expect(e.class).to eq(CoroutineRejection)
                        @log << e.message
                        @log << e.value
                    end
                }

                expect(@log).to eq(['foo', 'foo'])
            end

            it "should pass through exceptions without modification" do
                @reactor.run {
                    @reactor.next_tick do
                        @deferred.reject(RuntimeError.new('fail'))
                    end

                    begin
                        @deferred.value
                        @log << 'should raise exception'
                    rescue => e
                        expect(e.class).to eq(RuntimeError)
                        @log << e.message
                    end
                }

                expect(@log).to eq(['fail'])
            end
        end
        
    end
    
    
    
    describe 'reject' do
        
        it "should package a string into a rejected promise" do
            @reactor.run {
                rejectedPromise = MTLibuv::Q.reject(@reactor, 'not gonna happen')
                
                @promise.then(@default_fail, proc {|reason|
                    @log << reason
                })
                
                @deferred.resolve(rejectedPromise)
            }

            expect(@log).to eq(['not gonna happen'])
        end
        
        
        it "should return a promise that forwards callbacks if the callbacks are missing" do
            @reactor.run {
                rejectedPromise = MTLibuv::Q.reject(@reactor, 'not gonna happen')
                
                @promise.then(@default_fail, proc {|reason|
                    @log << reason
                })
                
                @deferred.resolve(rejectedPromise.then())
            }

            expect(@log).to eq(['not gonna happen'])
        end
        
    end
    
    
    
    describe 'all' do
        
        it "should resolve all of nothing" do
            @reactor.run {
                MTLibuv::Q.all(@reactor).then nil, @default_fail do |result|
                    @log << result
                end
            }

            expect(@log).to eq([[]])
        end
        
        it "should take an array of promises and return a promise for an array of results" do
            @reactor.run {
                deferred1 = @reactor.defer
                deferred2 = @reactor.defer
                
                MTLibuv::Q.all(@reactor, @promise, deferred1.promise, deferred2.promise).then nil, @default_fail do |result|
                    @log = result
                end
                
                @reactor.work { @deferred.resolve(:foo) }
                @reactor.work { deferred2.resolve(:baz) }
                @reactor.work { deferred1.resolve(:bar) }
            }

            expect(@log).to eq([:foo, :bar, :baz])
        end
        
        
        it "should reject the derived promise if at least one of the promises in the array is rejected" do
            @reactor.run {
                deferred1 = @reactor.defer
                deferred2 = @reactor.defer
                
                MTLibuv::Q.all(@reactor, @promise, deferred1.promise, deferred2.promise).then(@default_fail, proc {|reason|
                    @log << reason
                })
                
                @reactor.work { @deferred.resolve(:foo) }
                @reactor.work { deferred2.reject(:baz) }
            }

            expect(@log).to eq([:baz])
        end
        
    end

    describe 'any' do
        
        it "should resolve any of nothing" do
            @reactor.run {
                MTLibuv::Q.any(@reactor).then nil, @default_fail do |result|
                    @log = result
                end
            }

            expect(@log).to eq(true)
        end
        
        it "should take an array of promises and return the first to succeed" do
            @reactor.run {
                deferred1 = @reactor.defer
                deferred2 = @reactor.defer
                
                MTLibuv::Q.any(@reactor, @promise, deferred1.promise, deferred2.promise).then nil, @default_fail do |result|
                    @log = result
                end
                
                @reactor.work {
                    @deferred.resolve(:foo)
                    deferred2.resolve(:baz)
                    deferred1.resolve(:bar)
                }
            }

            expect(@log).to eq(:foo)
        end
        
        
        it "should take an array of promises and return the first to fail" do
            @reactor.run {
                deferred1 = @reactor.defer
                deferred2 = @reactor.defer
                
                MTLibuv::Q.any(@reactor, @promise, deferred1.promise, deferred2.promise).then(@default_fail, proc { |result|
                    @log = result
                })
                
                @reactor.work {
                    @deferred.reject(:foo)
                    deferred2.resolve(:baz)
                }
            }

            expect(@log).to eq(:foo)
        end

    end

end
