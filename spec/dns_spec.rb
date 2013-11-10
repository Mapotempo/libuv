require 'libuv'


describe Libuv::Dns do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
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
	
	it "should resolve localhost using IP4" do
		@loop.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@loop.lookup('localhost').then proc { |addrinfo|
				@result = addrinfo[0][0]
				@loop.stop
			}, proc { |err|
				@general_failure << err
				@loop.stop
			}
		}

		@general_failure.should == []
		@result.should == '127.0.0.1'
	end

	it "should resolve localhost using IP6" do
		@loop.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				rescue Exception
					p 'error in logger'
				end
			end

			@loop.lookup('localhost', :IPv6).then proc { |addrinfo|
				@result = addrinfo[0][0]
				@loop.stop
			}, proc { |err|
				@general_failure << err
				@loop.stop
			}
		}

		@general_failure.should == []
		@result.should == '::1'
	end
end
