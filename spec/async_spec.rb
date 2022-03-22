require 'mt-libuv'


describe MTLibuv::Async do
	before :each do
		@log = []
		@general_failure = []

		@reactor = MTLibuv::Reactor.default
		@call = @reactor.pipe
		@timeout = @reactor.timer do
			@reactor.stop
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@reactor.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			puts "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
		end

		@reactor.notifier do |error, context|
			begin
				puts "Log called: #{context}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
			rescue Exception
				puts 'error in logger'
			end
		end
	end

	after :each do
		@reactor.notifier
	end
	
	it "Should call the async function from the thread pool stopping the counter" do
		@reactor.run { |reactor|

			@count = 0

			timer = @reactor.timer do
				@count += 1
			end
			timer.start(0, 200)

			callback = @reactor.async do
				stopper = @reactor.timer do
					timer.close
					callback.close
					stopper.close
					@timeout.close
					@reactor.stop
				end
				stopper.start(1000)
				callback.close
			end

			@reactor.work {
				callback.call
			}.catch do |err|
				@general_failure << err
			end
		}

		expect(@general_failure).to eq([])
		expect(@count < 7 && @count > 3).to eq(true)
	end
end
