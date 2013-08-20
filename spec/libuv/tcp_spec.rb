require 'libuv'


describe Libuv::TCP do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.tcp
		@client = @loop.tcp
		@timeout = @loop.timer
		@timeout.start(3000) do
			@loop.stop
			@general_failure << "test timed out"
		end

		@loop.all(@loop, @server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end
	end

	after :each do
		@general_failure.should == []
	end
	
	describe 'basic client server' do
		it "should send a ping and return a pong" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					p "Log called: #{level}: #{errorid}\n#{e.message}\n#{e.backtrace.join("\n")}\n"
				end






				# connect client to server
				@cbinding = @client.connect('127.0.0.1', 34567) do |client|
					p 'in callback'
					cbinding.progress do |data|
						@log << data

						p "client: #{data}"
						@client.shutdown
						@server.close
					end

					@client.write('ping')
				end

				# catch errors
				@cbinding.catch do |reason|
					@general_failure << reason.inspect
				end

				# close the handle
				@cbinding.finally do
					@client.close
				end
				
			}

			@log.should == ['ping', 'pong']
		end
	end
end
