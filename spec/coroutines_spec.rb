require 'libuv'

# No support for Fibers in jRuby
if RUBY_PLATFORM != 'java'
	require 'libuv/coroutines' # adds support for coroutines


	describe Object do
		before :each do
			@log = []
			@general_failure = []

			@loop = Libuv::Loop.default
			@timeout = @loop.timer do
				@timeout.close
				@loop.stop
				@general_failure << "test timed out"
			end
			@timeout.start(5000)
		end
		
		describe 'serial execution' do
			it "should wait for work to complete and return the result" do
				@loop.run { |logger|
					logger.progress do |level, errorid, error|
						begin
							@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
						rescue Exception => e
							@general_failure << "error in logger #{e.inspect}"
						end
					end


					@log << co(@loop.work(proc {
						sleep 1
						'work done'
					}))
					@log << 'after work'

					@timeout.close
					@loop.stop
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['work done', 'after work'])
			end

			it "should raise an error if the promise is rejected" do
				@loop.run { |logger|
					logger.progress do |level, errorid, error|
						begin
							@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
						rescue Exception => e
							@general_failure << "error in logger #{e.inspect}"
						end
					end

					begin
						@log << co(@loop.work(proc {
							raise 'rejected'
						}))
						@log << 'after work'
					rescue => e
						@log << e.message
					end

					@timeout.close
					@loop.stop
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['rejected'])
			end

			it "should return the results of multiple promises" do
				@loop.run { |logger|
					logger.progress do |level, errorid, error|
						begin
							@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
						rescue Exception => e
							@general_failure << "error in logger #{e.inspect}"
						end
					end


					job1 = @loop.work(proc {
						sleep 1
						'job1'
					})

					job2 = @loop.work(proc {
						sleep 1
						'job2'
					})

					# Job1 and Job2 are executed in parallel
					result1, result2 = co(job1, job2)

					@log << result1
					@log << result2
					@log << 'after work'

					@timeout.close
					@loop.stop
				}

				expect(@general_failure).to eq([])
				expect(@log).to eq(['job1', 'job2', 'after work'])
			end


			it "should provide a callback option for progress events" do
				@loop.run { |logger|
					logger.progress do |level, errorid, error|
						begin
							@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
						rescue Exception => e
							@general_failure << "error in logger #{e.inspect}"
						end
					end

					timer = @loop.timer
					timer.start(0)
					co(timer) do
						@log << 'in timer'
						timer.close  # close will resolve the promise
					end

					@log << 'after timer'

					@timeout.close
					@loop.stop
				}

				expect(@log).to eq(['in timer', 'after timer'])
				expect(@general_failure).to eq([])
			end
		end
	end
end
