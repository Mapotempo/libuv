require 'mt-libuv'
require 'thread'


describe MTLibuv::TCP do
	before :each do
		@log = []
		@general_failure = []

		@reactor = MTLibuv::Reactor.new
		@server = @reactor.tcp
		@client = @reactor.tcp
		@timeout = @reactor.timer do
			@reactor.stop
			@reactor2.stop if @reactor2
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@reactor.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end


		@pipefile = "/tmp/test-pipe.pipe"
		@reactor.notifier do |error, context|
			begin
				@general_failure << "Log called: #{context}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
			rescue Exception => e
				@general_failure << "error in logger #{e.inspect}"
			end
		end

		begin
			File.unlink(@pipefile)
		rescue
		end
	end
	
	describe 'basic client server' do
		it "should send a ping and return a pong", :network => true do
			@reactor.run { |reactor|
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
					@reactor.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong'])
		end

		it "should work with coroutines", :network => true do
			@reactor.run { |reactor|
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
				@client.progress do |data|
					@log << data

					addrinfo = @reactor.lookup('127.0.0.1')
					@log << addrinfo[0][0]

					@client.shutdown
				end
				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
				end

				# close the handle
				@client.finally do
					@server.close
					@reactor.stop
				end
				@client.connect('127.0.0.1', 34567)
				@client.start_read
				@client.write('ping')
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong', '127.0.0.1'])
		end

		it "should quack a bit like an IO object", :network => true do
			@reactor.run { |reactor|
				@server.bind('127.0.0.1', 34567) do |client|
					@log << client.read(4)
					client.write('pong')
				end

				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
				end

				# start listening
				@server.listen(1024)

				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
				end

				# close the handle
				@client.finally do
					@server.close
					@reactor.stop
				end
				@client.connect('127.0.0.1', 34567)
				@client.write('ping')
				@log << @client.read(4)
				addrinfo = @reactor.lookup('127.0.0.1')
				@log << addrinfo[0][0]
				@client.shutdown
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong', '127.0.0.1'])
		end
	end

	it "should handle requests on different threads", :network => true do
		@sync = Mutex.new

		@reactor.run { |reactor|
			@remote = nil
			@server.bind('127.0.0.1', 45678) do |client|
				@remote.write2(client)
			end

			# catch errors
			@server.catch do |reason|
				@general_failure << reason.inspect
			end


			@pipeserve = @reactor.pipe(true)
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
				@reactor2 = MTLibuv::Reactor.new
				@reactor2.notifier do |error, context|
					begin
						@general_failure << "Log called: #{context}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
					rescue Exception
						@general_failure << "error in logger #{e.inspect}"
					end
				end
				@pipeclient = @reactor2.pipe(true)


				@reactor2.run do  |reactor|
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
								@reactor2.stop
								@reactor.stop
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
end
