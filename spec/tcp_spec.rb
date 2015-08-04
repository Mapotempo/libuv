require 'libuv'
require 'thread'


describe Libuv::TCP do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.tcp
		@client = @loop.tcp
		@timeout = @loop.timer do
			@loop.stop
			@loop2.stop if @loop2
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end


		@pipefile = "/tmp/test-pipe.pipe"

		begin
			File.unlink(@pipefile)
		rescue
		end
	end
	
	describe 'basic client server' do
		it "should send a ping and return a pong", :network => true do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					begin
						@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
					rescue Exception => e
						@general_failure << "error in logger #{e.inspect}"
					end
				end


				@server.bind('127.0.0.1', 34567) do |client|
					client.progress do |data|
						@log << data

						client.write('pong')
					end
					client.start_read
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

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong'])
		end
	end

	it "should handle requests on different threads", :network => true do
		@sync = Mutex.new

		@loop.run { |logger|
			logger.progress do |level, errorid, error|
				begin
					@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
				rescue Exception
					@general_failure << "error in logger #{e.inspect}"
				end
			end


			@remote = nil
			@server.bind('127.0.0.1', 45678) do |client|
				@remote.write2(client)
			end

			# catch errors
			@server.catch do |reason|
				@general_failure << reason.inspect
			end


			@pipeserve = @loop.pipe(true)
			@pipeserve.bind(@pipefile) do |client|
				@remote = client

				# start listening on TCP server
				@server.listen(1024)

				# connect client to server
				@client.connect('127.0.0.1', 45678) do |client|
					client.progress do |data|
						@sync.synchronize {
							@log << data
						}
						@client.shutdown
					end

					@client.start_read
					@client.write('ping')
				end

				@pipeserve.getsockname
			end

			# start listening
			@pipeserve.listen(1024)



			# catch errors
			@client.catch do |reason|
				@general_failure << reason.inspect
			end

			# close the handle
			@client.finally do
				@server.close
				@pipeserve.close
			end
			


			Thread.new do
				@loop2 = Libuv::Loop.new
				@pipeclient = @loop2.pipe(true)


				@loop2.run do  |logger|
					logger.progress do |level, errorid, error|
						begin
							@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
						rescue Exception
							@general_failure << "error in logger #{e.inspect}"
						end
					end
			
					# connect client to server
					@pipeclient.connect(@pipefile) do |client|
						@pipeclient.progress do |data|
							connection = @pipeclient.check_pending

							connection.progress do |data|
								@sync.synchronize {
									@log << data
								}
								connection.write('pong')
							end
							connection.start_read
							connection.finally do
								@pipeclient.close
								@loop2.stop
								@loop.stop
							end
						end

						@pipeclient.start_read
					end
				end
			end
		}

		expect(@general_failure).to eq([])
		expect(@log).to eq(['ping', 'pong'])
	end

	describe 'basic TLS client and server' do
		it "should send a ping and return a pong", :network => true do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					begin
						@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
					rescue Exception
						@general_failure << "error in logger #{e.inspect}"
					end
				end


				@server.bind('127.0.0.1', 56789) do |client|
					client.start_tls(server: true)
					client.progress do |data|
						@log << data

						client.write('pong')
					end
					client.start_read
				end

				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
				end

				# start listening
				@server.listen(1024)



				# connect client to server
				@client.connect('127.0.0.1', 56789) do |client|
					client.start_tls
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

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong'])
		end
	end

end
