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
		@reactor.run { |reactor|
			reactor.notifier do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('localhost', wait: true).then proc { |addrinfo|
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
		@reactor.run { |reactor|
			reactor.notifier do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('localhost', :IPv6, wait: true).then proc { |addrinfo|
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
		@reactor.run { |reactor|
			reactor.notifier do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@reactor.lookup('127.0.0.1', wait: true).then proc { |addrinfo|
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

	it "should work with coroutines" do
		@reactor.run { |reactor|
			reactor.notifier do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			begin
				addrinfo = @reactor.lookup('127.0.0.1').results
				@result = [addrinfo[0][0]]

				begin
					addrinfo = @reactor.lookup('test.fail.blah').results
					@general_failure << "should have failed"
					@timeout.close
					@reactor.stop
				rescue => err 
					@result << err.class
					@timeout.close
					@reactor.stop
				end
			rescue => err 
				@general_failure << err
				@timeout.close
				@reactor.stop
			end
		}

		expect(@general_failure).to eq([])
		expect(@result).to eq(['127.0.0.1', Libuv::Error::EAI_NONAME])
	end
end
