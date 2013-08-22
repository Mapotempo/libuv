require 'libuv'


describe Libuv::TCP do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.tcp
		@client = @loop.tcp
		@timeout = @loop.timer do
			@loop.stop
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end
	end
	
	describe 'basic client server' do
		it "should send a ping and return a pong", :network => true do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					begin
						p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
					rescue Exception
						p 'error in logger'
					end
				end


				@server.bind('127.0.0.1', 34567) do |server|
					server.accept do |client|
						client.progress do |data|
							@log << data

							client.write('pong')
						end
						client.start_read
					end
				end

				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
				end

				# start listening
				@server.listen(1024)



				# connect client to server
				@client.connect('127.0.0.1', 34567) do |client|
					client.progress do |data|
						@log << data

						@client.shutdown
					end

					@client.start_read
					@client.write('ping')
				end

				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
				end

				# close the handle
				@client.finally do
					@server.close
					@loop.stop
				end
			}

			@general_failure.should == []
			@log.should == ['ping', 'pong']
		end

=begin
		it "should allow multiple binds to the same address" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					begin
						p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
					rescue Exception
						p 'error in logger'
					end
				end


				@server.bind('127.0.0.1', 34567) do |server|
					server.accept do |client|
						client.progress do |data|
							@log << data

							client.write('pong1')
						end
						client.start_read
					end
				end

				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
				end

				# start listening
				@server.listen(1024)


				@server2 = @loop.tcp

				@server2.bind('127.0.0.1', 34567) do |server|
					server.accept do |client|
						client.progress do |data|
							@log << data

							client.write('pong2')
						end
						client.start_read
					end
				end

				# catch errors
				@server2.catch do |reason|
					@general_failure << reason.inspect
				end

				# start listening
				@server2.listen(1024)


				# connect client to server
				@client.connect('127.0.0.1', 34567) do |client|
					client.progress do |data|
						@log << data

						@client.shutdown
					end

					@client.start_read
					@client.write('ping1')
				end

				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
				end

				# close the handle
				@client.finally do
					@server.close
					@loop.stop
				end

				@client2 = @loop.tcp

				# connect client to server
				@client2.connect('127.0.0.1', 34567) do |client|
					client.progress do |data|
						@log << data

						@client.shutdown
					end

					@client2.start_read
					@client2.write('ping2')
				end

				# catch errors
				@client2.catch do |reason|
					@general_failure << reason.inspect
				end

			}

			@general_failure.should == []
			@log.should == ['ping', 'pong']
		end
=end

	end
end
