require 'libuv'


describe Libuv::Dns do
	before :each do
		@log = []
		@general_failure = []

		@reactor = Libuv::Reactor.default
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
	
	it "should resolve localhost using IP4", :network => true do
		@reactor.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('localhost').then proc { |addrinfo|
				@result = addrinfo[0][0]
				@timeout.close
				@reactor.stop
			}, proc { |err|
				@general_failure << err
				@timeout.close
				@reactor.stop
			}
		}

		expect(@general_failure).to eq([])
		expect(@result).to eq('127.0.0.1')
	end

	it "should resolve localhost using IP6", :network => true do
		@reactor.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('localhost', :IPv6).then proc { |addrinfo|
				@result = addrinfo[0][0]
				@timeout.close
				@reactor.stop
			}, proc { |err|
				@general_failure << err
				@timeout.close
				@reactor.stop
			}
		}

		expect(@general_failure).to eq([])
		expect(@result).to eq('::1')
	end

	it "should resolve reactor back" do
		@reactor.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('127.0.0.1').then proc { |addrinfo|
				@result = addrinfo[0][0]
				@timeout.close
				@reactor.stop
			}, proc { |err|
				@general_failure << err
				@timeout.close
				@reactor.stop
			}
		}

		expect(@general_failure).to eq([])
		expect(@result).to eq('127.0.0.1')
	end
end
