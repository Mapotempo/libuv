require 'mt-libuv'

# No support for Fibers in jRuby
if RUBY_PLATFORM != 'java'
	require 'mt-libuv/coroutines' # adds support for coroutines


	describe Object do
		before :each do
			@log = []
			@general_failure = []

			@reactor = MTLibuv::Reactor.default
			@reactor.notifier do |error, context|
				begin
					@general_failure << "Log called: #{context}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
				rescue Exception => e
					@general_failure << "error in logger #{e.inspect}"
				end
			end

			@timeout = @reactor.timer do
				@timeout.close
				@reactor.stop
				@general_failure << "test timed out"
			end
			@timeout.start(5000)
		end
		
		describe 'serial execution' do
			it "should wait for work to complete and return the result" do
				@reactor.run { |reactor|

					@log << @reactor.work {
						sleep 1
						'work done'
					}.value
					@log << 'after work'

					@timeout.close
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['work done', 'after work'])
			end

			it "should raise an error if the promise is rejected" do
				@reactor.run { |reactor|
					begin
						@log << @reactor.work {
							raise 'rejected'
						}.value
						@log << 'after work'
					rescue => e
						@log << e.message
					end

					@timeout.close
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['rejected'])
			end

			it "should return the results of multiple promises" do
				@reactor.run { |reactor|
					job1 = @reactor.work {
						sleep 1
						'job1'
					}

					job2 = @reactor.work {
						sleep 1
						'job2'
					}

					# Job1 and Job2 are executed in parallel
					result1, result2 = ::MTLibuv.co(job1, job2)

					@log << result1
					@log << result2
					@log << 'after work'

					@timeout.close
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['job1', 'job2', 'after work'])
			end

			it "should provide a callback option for progress events" do
				@reactor.run { |reactor|
					timer = @reactor.timer
					timer.start(0)
					::MTLibuv.co(timer) do
						@log << 'in timer'
						timer.close  # close will resolve the promise
					end

					@log << 'after timer'
					@timeout.close
				}

				expect(@log).to eq(['in timer', 'after timer'])
				expect(@general_failure).to eq([])
			end

			it "should provide a sleep function that doesn't block the reactor" do
				@reactor.run { |reactor|
					@log << 'before sleep'
					reactor.sleep 200
					@log << 'after sleep'
					@timeout.close
				}

				expect(@log).to eq(['before sleep', 'after sleep'])
				expect(@general_failure).to eq([])
			end
		end
	end
end
