require 'libuv'


describe Libuv::Q do
	
	before :each do
		@loop = Libuv::Loop.default
		@deferred = @loop.defer
		@promise = @deferred.promise
		@log = []
		@default_fail = proc { |reason|
			@loop.stop
		}
	end
	
	
	describe 'resolve' do
		
		
		it "should call the callback in the next turn" do
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << result
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq([:foo])
		end
		
		
		
		it "should be able to resolve the callback after it has already been resolved" do
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << result
					@promise.then nil, @default_fail do |result|
						@log << result
					end
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.next_tick do
						@loop.stop
					end
				end
			}
			expect(@log).to eq([:foo, :foo])
		end
		
		
		
		it "should fulfill success callbacks in the registration order" do
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << :first
				end
				
				@promise.then nil, @default_fail do |result|
					@log << :second
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.stop
				end
			}
			expect(@log).to eq([:first, :second])
		end
		
		
		it "should do nothing if a promise was previously resolved" do
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << result
					expect(@log).to eq([:foo])
					@deferred.resolve(:bar)
				end
				
				@deferred.resolve(:foo)
				@deferred.reject(:baz)
				
				#
				# 4 ticks should detect any errors
				#
				@loop.next_tick do
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.stop
							end
						end
					end
				end
			}
			expect(@log).to eq([:foo])
		end
		
		
		it "should allow deferred resolution with a new promise" do
			deferred2 = @loop.defer
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << result
					@loop.stop
				end
				
				@deferred.resolve(deferred2.promise)
				deferred2.resolve(:foo)
			}
			expect(@log).to eq([:foo])
		end
		
		
		it "should not break if a callbacks registers another callback" do
			@loop.run {
				@promise.then nil, @default_fail do |result|
					@log << :outer
					@promise.then nil, @default_fail do |result|
						@log << :inner
					end
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.next_tick do
						@loop.stop
					end
				end
			}

			expect(@log).to eq([:outer, :inner])
		end
		
		
		
		it "can modify the result of a promise before returning" do
			@loop.run {
				proc { |name|
					@loop.work { @deferred.resolve("Hello #{name}") }
					@promise.then nil, @default_fail do |result|
						@log << result
						result += "?"
						result
					end
				}.call('Robin Hood').then nil, @default_fail do |greeting|
					@log << greeting
					@loop.stop
				end
			}

			expect(@log).to eq(['Hello Robin Hood', 'Hello Robin Hood?'])
		end
	
	end
	
	
	describe 'reject' do
	
		it "should reject the promise and execute all error callbacks" do
			@loop.run {
				@promise.then(@default_fail, proc {|result|
					@log << :first
				})
				@promise.then(@default_fail, proc {|result|
					@log << :second
				})
				
				@deferred.reject(:foo)
				
				@loop.next_tick do
					@loop.stop
				end
			}
			expect(@log).to eq([:first, :second])
		end
		
		
		it "should do nothing if a promise was previously rejected" do
			@loop.run {
				@promise.then(@default_fail, proc {|result|
					@log << result
					@deferred.resolve(:bar)
				})
				
				@deferred.reject(:baz)
				@deferred.resolve(:foo)
				
				#
				# 4 ticks should detect any errors
				#
				@loop.next_tick do
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.stop
							end
						end
					end
				end
			}
			expect(@log).to eq([:baz])
		end
		
		
		it "should not defer rejection with a new promise" do
			deferred2 = @loop.defer
			@loop.run {
				@promise.then(@default_fail, @default_fail)
				begin
					@deferred.reject(deferred2.promise)
				rescue => e
					@log << e.is_a?(ArgumentError)
					@loop.stop
				end
			}

			expect(@log).to eq([true])
		end
		
	end


	describe 'notify' do
		it "should execute all progress callbacks in the registration order" do
			@loop.run {
				@promise.progress do |update|
					@log << :first
				end
				
				@promise.progress do |update|
					@log << :second
				end
				
				@deferred.notify(:foo)
				
				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq([:first, :second])
		end

		it "should do nothing if a promise was previously resolved" do
			@loop.run {

				@promise.progress do |update|
					@log << update
				end

				@deferred.resolve(:foo)
				@deferred.notify(:baz)
				
				
				#
				# 4 ticks should detect any errors
				#
				@loop.next_tick do
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.stop
							end
						end
					end
				end
			}

			expect(@log).to eq([])
		end

		it "should do nothing if a promise was previously rejected" do
			@loop.run {

				@promise.progress do |update|
					@log << update
				end
				@deferred.reject(:foo)
				@deferred.notify(:baz)
				
				
				
				#
				# 4 ticks should detect any errors
				#
				@loop.next_tick do
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.stop
							end
						end
					end
				end
			}

			expect(@log).to eq([])
		end


		it "should not apply any special treatment to promises passed to notify" do
			@loop.run {
				deferred2 = @loop.defer

				@promise.progress do |update|
					@log << update.is_a?(::Libuv::Q::Promise)
				end
				@deferred.notify(deferred2.promise)

				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq([true])
		end


		it "should call the progress callbacks in the next turn" do
			@loop.run {
				@promise.progress do |update|
					@log << :first
				end
				
				@promise.progress do |update|
					@log << :second
				end
				
				@deferred.notify(:foo)
				
				@log << @log.length	# Has notify run in this tick
				@loop.stop	# Stop will run through the next tick before stopping
			}

			expect(@log).to eq([0, :first, :second])
		end

		it "should ignore notifications sent out in the same turn before listener registration" do
			@loop.run {
				@deferred.notify(:foo)

				@promise.progress do |update|
					@log << :first
				end
				
				@promise.progress do |update|
					@log << :second
				end
				
				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq([])
		end
	end
	
	
	describe Libuv::Q::Promise do
		
		describe 'then' do
			
			it "should allow registration of a success callback without an errback and resolve" do
				@loop.run {
					@promise.then do |result|
						@log << result
					end

					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([:foo])
			end
			
			
			it "should allow registration of a success callback without an errback and reject" do
				@loop.run {
					@promise.then do |result|
						@log << result
					end

					@deferred.reject(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([])
			end
			
			
			it "should allow registration of an errback without a success callback and reject" do
				@loop.run {
					@promise.catch(proc {|reason|
						@log << reason
					})

					@deferred.reject(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([:foo])
			end
			
			
			it "should allow registration of an errback without a success callback and resolve" do
				@loop.run {
					@promise.catch(proc {|reason|
						@log << reason
					})

					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([])
			end
			
			
			it "should resolve all callbacks with the original value" do
				@loop.run {
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
						Libuv::Q.reject(@loop, 'some reason')
					end
					@promise.then nil, @default_fail do |result|
						@log << result
						:alt2
					end
					
					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([:foo, :foo, :foo, :foo])
			end


			it "should notify all callbacks with the original value" do
				@loop.run { |loop_promise|
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
						Libuv::Q.reject(@loop, 'some reason')
					end
					@promise.progress do |result|
						@log << result
						:alt2
					end

					
					@deferred.notify(:foo)
					
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.stop
									end
								end
							end
						end
					end
				}

				expect(@log).to eq([:foo, :foo, :foo, :foo])
			end
			
			
			it "should reject all callbacks with the original reason" do
				@loop.run {
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
						Libuv::Q.reject(@loop, 'some reason')
					})
					@promise.then(@default_fail, proc {|result|
						@log << result
						:alt2
					})
					
					@deferred.reject(:foo)
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([:foo, :foo, :foo, :foo])
			end
			
			
			it "should propagate resolution and rejection between dependent promises" do
				@loop.run {
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
					
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.next_tick do 	# extra tick?
											@loop.stop
										end
									end
								end
							end
						end
					end
				}

				expect(@log).to eq([:foo, :bar, 'baz', 'bob', :done])
			end


			it "should propagate notification between dependent promises" do
				@loop.run { |loop_promise|
					loop_promise.progress do |type, id, error|
						@log << id
					end


					@promise.progress(proc { |result|
						@log << result
						:bar
					}).progress(proc { |result|
						@log << result
						result
					}).progress(proc {|result|
						@log << result
						result
					}).progress(proc {|result|
						@log << result
						:done
					}).progress(proc { |result|
						@log << result
						result
					})

					
					@deferred.notify(:foo)
					
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.next_tick do # extra tick?
											@loop.stop
										end
									end
								end
							end
						end
					end
				}

				expect(@log).to eq([:foo, :bar, :bar, :bar, :done])
			end


			it "should stop notification propagation in case of error" do
				@loop.run { |loop_logger|
					loop_logger.progress do |type, id, error|
						@log << id
					end


					@promise.progress(proc { |result|
						@log << result
						:bar
					}).progress(proc { |result|
						@log << result
						raise 'err'
						result
					}).progress(proc {|result|
						@log << result
						result
					}).progress(proc {|result|
						@log << result
						:done
					}).progress(proc { |result|
						@log << result
						result
					})

					
					@deferred.notify(:foo)
					
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.stop
									end
								end
							end
						end
					end
				}

				expect(@log).to eq([:foo, :bar, :q_progress_cb])
			end
			
			
			it "should call error callback in the next turn even if promise is already rejected" do
				@loop.run {
					@deferred.reject(:foo)
					
					@promise.catch(proc {|reason|
						@log << reason
					})
					
					@loop.next_tick do
						@loop.stop
					end
				}

				expect(@log).to eq([:foo])
			end
			
			
		end


		describe 'finally' do

			describe 'when the promise is fulfilled' do

				it "should call the callback" do
					@loop.run {
						@promise.finally do
							@log << :finally
						end

						@deferred.resolve(:foo)
						
						@loop.next_tick do
							@loop.stop
						end
					}

					expect(@log).to eq([:finally])
				end

				it "should fulfill with the original value" do
					@loop.run {
						@promise.finally(proc {
							@log << :finally
							:finally
						}).then do |result|
							@log << result
						end
						

						@deferred.resolve(:foo)
						
						@loop.next_tick do
							@loop.next_tick do
								@loop.stop
							end
						end
					}

					expect(@log).to eq([:finally, :foo])
				end

				it "should fulfill with the original value (larger test)" do
					@loop.run {
						@promise.then(proc { |result|
							@log << result
							result
						}).finally(proc {
							@log << :finally
							:finally
						}).then(proc { |result|
							@log << result
							:change
						}).then(proc { |result|
							@log << result
							result
						}).finally(proc {
							@log << :finally
							:finally
						}).then(proc { |result|
							@log << result
							result
						})
						

						@deferred.resolve(:foo)

						
						@loop.next_tick do
						@loop.next_tick do
						@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.next_tick do
											@loop.stop
										end
									end
								end
							end
						end
						end
						end
						end
					}

					expect(@log).to eq([:foo, :finally, :foo, :change, :finally, :change])
				end

				describe "when the callback throws an exception" do
					it "should reject with this new exception" do
						@loop.run {
							@promise.finally(proc {
								@log << :finally
								raise 'error'
							}).catch do |reason|
								@log.push reason.is_a?(Exception)
							end
							
							@deferred.resolve(:foo)
							
							@loop.next_tick do
								@loop.next_tick do
									@loop.stop
								end
							end
						}

						expect(@log).to eq([:finally, true])
					end
				end

				describe "when the callback returns a promise" do
					it "should fulfill with the original reason after that promise resolves" do
						@loop.run {
							deferred2 = @loop.defer

							@promise.finally(proc {
								@log << :finally
								deferred2.promise
							}).then do |result|
								@log << result
							end
							
							@deferred.resolve(:foo)
							
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.next_tick do
											@log << :resolving
											deferred2.resolve('working')
											@loop.next_tick do
												@loop.next_tick do
													@loop.stop
												end
											end
										end
									end
								end
							end
						}

						expect(@log).to eq([:finally, :resolving, :foo])
					end


					it "should reject with the new reason when it is rejected" do
						@loop.run {
							deferred2 = @loop.defer

							@promise.finally(proc {
								@log << :finally
								deferred2.promise
							}).catch do |result|
								@log << result
							end
							
							@deferred.resolve(:foo)
							
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@loop.next_tick do
											@log << :rejecting
											deferred2.reject(:rejected)
											@loop.next_tick do
												@loop.next_tick do
													@loop.stop
												end
											end
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
		
	end
	
	
	
	describe 'reject' do
		
		it "should package a string into a rejected promise" do
			@loop.run {
				rejectedPromise = Libuv::Q.reject(@loop, 'not gonna happen')
				
				@promise.then(@default_fail, proc {|reason|
					@log << reason
				})
				
				@deferred.resolve(rejectedPromise)
				
				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq(['not gonna happen'])
		end
		
		
		it "should return a promise that forwards callbacks if the callbacks are missing" do
			@loop.run {
				rejectedPromise = Libuv::Q.reject(@loop, 'not gonna happen')
				
				@promise.then(@default_fail, proc {|reason|
					@log << reason
				})
				
				@deferred.resolve(rejectedPromise.then())
				
				@loop.next_tick do
					@loop.next_tick do
						@loop.stop
					end
				end
			}

			expect(@log).to eq(['not gonna happen'])
		end
		
	end
	
	
	
	describe 'all' do
		
		it "should resolve all of nothing" do
			@loop.run {
				Libuv::Q.all(@loop).then nil, @default_fail do |result|
					@log << result
				end
				
				@loop.next_tick do
					@loop.stop
				end
			}

			expect(@log).to eq([[]])
		end
		
		it "should take an array of promises and return a promise for an array of results" do
			@loop.run {
				deferred1 = @loop.defer
				deferred2 = @loop.defer
				
				Libuv::Q.all(@loop, @promise, deferred1.promise, deferred2.promise).then nil, @default_fail do |result|
					@log = result
					@loop.stop
				end
				
				@loop.work { @deferred.resolve(:foo) }
				@loop.work { deferred2.resolve(:baz) }
				@loop.work { deferred1.resolve(:bar) }
			}

			expect(@log).to eq([:foo, :bar, :baz])
		end
		
		
		it "should reject the derived promise if at least one of the promises in the array is rejected" do
			@loop.run {
				deferred1 = @loop.defer
				deferred2 = @loop.defer
				
				Libuv::Q.all(@loop, @promise, deferred1.promise, deferred2.promise).then(@default_fail, proc {|reason|
					@log << reason
					@loop.stop
				})
				
				@loop.work { @deferred.resolve(:foo) }
				@loop.work { deferred2.reject(:baz) }
			}

			expect(@log).to eq([:baz])
		end
		
	end

end
