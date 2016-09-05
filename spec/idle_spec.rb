require 'libuv'


describe Libuv::Idle do
	before :each do
		@log = []
		@general_failure = []

		@reactor = Libuv::Reactor.default
		@timeout = @reactor.timer {
			@reactor.stop
			@general_failure << "test timed out"
		}.start(5000)
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
  
			idle = @reactor.idle { |e|
				@idle_calls += 1
			}.start

			stopper = @reactor.timer {
				idle.stop.close
				stopper.close
				@timeout.close
				@reactor.stop
			}.start(1000)
		}

		expect(@general_failure).to eq([])
		expect((@idle_calls > 0)).to eq(true)
	end
end
