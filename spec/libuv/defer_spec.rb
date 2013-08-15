require 'libuv'


describe Libuv::Q do
	
	before :each do
		@loop = Libuv::Loop.new
		@deferred = @loop.defer
		@promise = @deferred.promise
		@log = []
		@default_fail = proc { |reason|
			fail(reason)
			@loop.stop
		}
	end
	
	
	describe 'resolve' do
		
		
		it "should call the callback in the next turn" do
			@loop.run {
				@promise.then @default_fail do |result|
					@log << result
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@log.should == [:foo]
					@loop.stop
				end
			}
		end
		
		
		
		it "should be able to resolve the callback after it has already been resolved" do
			deferred2 = @loop.defer
			@loop.run {
				@promise.then @default_fail do |result|
					@log << result
					@promise.then @default_fail do |result|
						@log << result
					end
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.next_tick do
						@log.should == [:foo, :foo]
						@loop.stop
					end
				end
			}
		end
		
		
		
		it "should fulfill success callbacks in the registration order" do
			@loop.run {
				@promise.then @default_fail do |result|
					@log << :first
				end
				
				@promise.then @default_fail do |result|
					@log << :second
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@log.should == [:first, :second]
					@loop.stop
				end
			}
		end
		
		
		it "should do nothing if a promise was previously resolved" do
			@loop.run {
				@promise.then @default_fail do |result|
					@log << result
					@log.should == [:foo]
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
								@log.should == [:foo]
								@loop.stop
							end
						end
					end
				end
			}
		end
		
		
		it "should allow deferred resolution with a new promise" do
			deferred2 = @loop.defer
			@loop.run {
				@promise.then @default_fail do |result|
					result.should == :foo
					@loop.stop
				end
				
				@deferred.resolve(deferred2.promise)
				deferred2.resolve(:foo)
			}
		end
		
		
		it "should not break if a callbacks registers another callback" do
			@loop.run {
				@promise.then @default_fail do |result|
					@log << :outer
					@promise.then @default_fail do |result|
						@log << :inner
					end
				end
				
				@deferred.resolve(:foo)
				
				@loop.next_tick do
					@loop.next_tick do
						@log.should == [:outer, :inner]
						@loop.stop
					end
				end
			}
		end
		
		
		
		it "can modify the result of a promise before returning" do
			@loop.run {
				proc { |name|
					@loop.work { @deferred.resolve("Hello #{name}") }
					@promise.then @default_fail do |result|
						result.should == 'Hello Robin Hood'
						result += "?"
						result
					end
				}.call('Robin Hood').then @default_fail do |greeting|
					greeting.should == 'Hello Robin Hood?'
					@loop.stop
				end
			}
		end
	
	end
	
	
	describe 'reject' do
	
		it "should reject the promise and execute all error callbacks" do
			@loop.run {
				@promise.then(proc {|result|
					@log << :first
				}, @default_fail)
				@promise.then(proc {|result|
					@log << :second
				}, @default_fail)
				
				@deferred.reject(:foo)
				
				@loop.next_tick do
					@log.should == [:first, :second]
					@loop.stop
				end
			}
		end
		
		
		it "should do nothing if a promise was previously rejected" do
			@loop.run {
				@promise.then(proc {|result|
					@log << result
					@log.should == [:baz]
					@deferred.resolve(:bar)
				}, @default_fail)
				
				@deferred.reject(:baz)
				@deferred.resolve(:foo)
				
				#
				# 4 ticks should detect any errors
				#
				@loop.next_tick do
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@log.should == [:baz]
								@loop.stop
							end
						end
					end
				end
			}
		end
		
		
		it "should not defer rejection with a new promise" do
			deferred2 = @loop.defer
			@loop.run {
				@promise.then(@default_fail, @default_fail)
				begin
					@deferred.reject(deferred2.promise)
				rescue => e
					e.is_a?(ArgumentError).should == true
					@loop.stop
				end
			}
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
						@log.should == [:foo]
						@loop.stop
					end
				}
			end
			
			
			it "should allow registration of a success callback without an errback and reject" do
				@loop.run {
					@promise.then do |result|
						@log << result
					end

					@deferred.reject(:foo)
					
					@loop.next_tick do
						@log.should == []
						@loop.stop
					end
				}
			end
			
			
			it "should allow registration of an errback without a success callback and reject" do
				@loop.run {
					@promise.then(proc {|reason|
						@log << reason
					})

					@deferred.reject(:foo)
					
					@loop.next_tick do
						@log.should == [:foo]
						@loop.stop
					end
				}
			end
			
			
			it "should allow registration of an errback without a success callback and resolve" do
				@loop.run {
					@promise.then(proc {|reason|
						@log << reason
					})

					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@log.should == []
						@loop.stop
					end
				}
			end
			
			
			it "should resolve all callbacks with the original value" do
				@loop.run {
					@promise.then @default_fail do |result|
						@log << result
						:alt1
					end
					@promise.then @default_fail do |result|
						@log << result
						'ERROR'
					end
					@promise.then @default_fail do |result|
						@log << result
						Libuv::Q.reject(@loop, 'some reason')
					end
					@promise.then @default_fail do |result|
						@log << result
						:alt2
					end
					
					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@log.should == [:foo, :foo, :foo, :foo]
						@loop.stop
					end
				}
			end
			
			
			it "should reject all callbacks with the original reason" do
				@loop.run {
					@promise.then(proc {|result|
						@log << result
						:alt1
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						'ERROR'
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						Libuv::Q.reject(@loop, 'some reason')
					}, @default_fail)
					@promise.then(proc {|result|
						@log << result
						:alt2
					}, @default_fail)
					
					@deferred.reject(:foo)
					
					@loop.next_tick do
						@log.should == [:foo, :foo, :foo, :foo]
						@loop.stop
					end
				}
			end
			
			
			it "should propagate resolution and rejection between dependent promises" do
				@loop.run {
					@promise.then(@default_fail, proc { |result|
						@log << result
						:bar
					}).then(@default_fail, proc { |result|
						@log << result
						raise 'baz'
					}).then(proc {|result|
						@log << result.message
						raise 'bob'
					}, @default_fail).then(proc {|result|
						@log << result.message
						:done
					}, @default_fail).then(@default_fail, proc { |result|
						@log << result
					})
					
					@deferred.resolve(:foo)
					
					@loop.next_tick do
						@loop.next_tick do
							@loop.next_tick do
								@loop.next_tick do
									@loop.next_tick do
										@log.should == [:foo, :bar, 'baz', 'bob', :done]
										@loop.stop
									end
								end
							end
						end
					end
				}
			end
			
			
			it "should call error callback in the next turn even if promise is already rejected" do
				@loop.run {
					@deferred.reject(:foo)
					
					@promise.then(proc {|reason|
						@log << reason
					})
					
					@loop.next_tick do
						@log.should == [:foo]
						@loop.stop
					end
				}
			end
			
			
		end
		
	end
	
	
	
	describe 'reject' do
		
		it "should package a string into a rejected promise" do
			@loop.run {
				rejectedPromise = Libuv::Q.reject(@loop, 'not gonna happen')
				
				@promise.then(proc {|reason|
					@log << reason
				}, @default_fail)
				
				@deferred.resolve(rejectedPromise)
				
				@loop.next_tick do
					@log.should == ['not gonna happen']
					@loop.stop
				end
			}
		end
		
		
		it "should return a promise that forwards callbacks if the callbacks are missing" do
			@loop.run {
				rejectedPromise = Libuv::Q.reject(@loop, 'not gonna happen')
				
				@promise.then(proc {|reason|
					@log << reason
				}, @default_fail)
				
				@deferred.resolve(rejectedPromise.then())
				
				@loop.next_tick do
					@loop.next_tick do
						@log.should == ['not gonna happen']
						@loop.stop
					end
				end
			}
		end
		
	end
	
	
	
	describe 'all' do
		
		it "should resolve all of nothing" do
			@loop.run {
				Libuv::Q.all(@loop).then @default_fail do |result|
					@log << result
				end
				
				@loop.next_tick do
					@log.should == [[]]
					@loop.stop
				end
			}
		end
		
		it "should take an array of promises and return a promise for an array of results" do
			@loop.run {
				deferred1 = @loop.defer
				deferred2 = @loop.defer
				
				Libuv::Q.all(@loop, @promise, deferred1.promise, deferred2.promise).then @default_fail do |result|
					result.should == [:foo, :bar, :baz]
					@loop.stop
				end
				
				@loop.work { @deferred.resolve(:foo) }
				@loop.work { deferred2.resolve(:baz) }
				@loop.work { deferred1.resolve(:bar) }
			}
		end
		
		
		it "should reject the derived promise if at least one of the promises in the array is rejected" do
			@loop.run {
				deferred1 = @loop.defer
				deferred2 = @loop.defer
				
				Libuv::Q.all(@loop, @promise, deferred1.promise, deferred2.promise).then(proc {|reason|
					reason.should == :baz
					@loop.stop
				}, @default_fail)
				
				@loop.work { @deferred.resolve(:foo) }
				@loop.work { deferred2.reject(:baz) }
			}
		end
		
	end
	


end
