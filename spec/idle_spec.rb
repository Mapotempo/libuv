require 'libuv'


describe Libuv::Idle do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.pipe
		@client = @loop.pipe
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
	
	it "should increase the idle count when there is nothing to process" do
		@loop.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@idle_calls = 0
  
			idle = @loop.idle do |e|
				@idle_calls += 1
			end
			idle.start

			timer = @loop.timer proc {}
			timer.start(1, 0)

			stopper = @loop.timer do
				idle.close
				timer.close
				stopper.close
				@loop.stop
			end
			stopper.start(1000, 0)
		}

		@general_failure.should == []
		(@idle_calls > 0).should == true
	end
end
