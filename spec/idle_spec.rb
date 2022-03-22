require 'mt-libuv'


describe MTLibuv::Idle do
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
		@timeout = @reactor.timer {
			@reactor.stop
			@general_failure << "test timed out"
		}.start(5000)
	end
	
	it "should increase the idle count when there is nothing to process" do
		@reactor.run { |reactor|
			@idle_calls = 0
  
			idle = @reactor.idle { |e|
				@idle_calls += 1
			}.start

			stopper = @reactor.timer {
				idle.stop.close
				stopper.close
				@timeout.close
				@reactor.stop
			}.start(1000)

			expect(@reactor.active_handles).to be >= 4
		}

		expect(@general_failure).to eq([])
		expect((@idle_calls > 0)).to eq(true)
	end
end
