require 'libuv'


describe Libuv::TCP do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.tcp
		@client = @loop.tcp
		@timeout = @loop.timer
		@timeout.start(5000) do
			@loop.stop
			@general_failure << "test timed out"
		end

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end
	end
	
	describe 'basic client server' do
		it "should send a ping and return a pong" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					p "Log called: #{level}: #{errorid}\n#{e.message}\n#{e.backtrace.join("\n")}\n"
				end


				binding = @server.bind('127.0.0.1', 34567)

				# catch server errors
				binding.catch do |reason|
					@general_failure << reason.inspect
				end

				# catch server exit
				binding.then do |result|
					@log << "server_#{result}"
				end

				# consume data as it is recieved
				binding.progress do |server|
					p 'progress on bind'
					server.accept.then do |client|
						p 'client accepted'
						@accepted = client
						client[:binding].progress do |data|
							@log << data
							p "server: #{data}"
							client[:handle].write('pong')
							client[:handle].shutdown
						end
						client[:handle].start_read
						client[:binding].then do
							client[:handle].close
						end
					end
				end

				# start listening
				@server.listen(1024)



				# connect client to server
				@cbinding = @client.connect('127.0.0.1', 34567) do |client|
					p 'in callback'
					cbinding.progress do |data|
						@log << data

						p "client: #{data}"
						@client.shutdown
						@server.close
					end

					@client.start_read
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

			@general_failure.should == []
			@log.should == ['ping', 'pong']
		end
	end
end
