require 'libuv'


describe Libuv::Idle do
	before :each do
		@log = []
		@general_failure = []

		@reactor = Libuv::Reactor.default
		@server = @reactor.pipe
		@client = @reactor.pipe
		@timeout = @reactor.timer do
			@reactor.stop
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@reactor.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
		end
	end
	
	it "should increase the idle count when there is nothing to process" do
		@reactor.run { |reactor|
			reactor.notifier do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@idle_calls = 0
  
			idle = @reactor.idle do |e|
				@idle_calls += 1
			end
			idle.start

			timer = @reactor.timer proc {}
			timer.start(1, 0)

			stopper = @reactor.timer do
				idle.close
				timer.close
				stopper.close
				@reactor.stop
			end
			stopper.start(1000, 0)
		}

		expect(@general_failure).to eq([])
		expect((@idle_calls > 0)).to eq(true)
	end
end
