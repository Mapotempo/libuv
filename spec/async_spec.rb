require 'libuv'


describe Libuv::Async do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@call = @loop.pipe
		@timeout = @loop.timer do
			@loop.stop
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
		end
	end
	
	it "Should call the async function from the thread pool stopping the counter" do
		@loop.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@count = 0

			timer = @loop.timer do
				@count += 1
			end
			timer.start(0, 200)

			callback = @loop.async do
				stopper = @loop.timer do
					timer.close
					callback.close
					stopper.close
					@loop.stop
				end
				stopper.start(1000)
			end

			@loop.work(proc {
				callback.call
			}).catch do |err|
				@general_failure << err
			end
		}

		@general_failure.should == []
		(@count < 7 && @count > 3).should == true
	end
end
