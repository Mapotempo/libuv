require 'libuv'


describe Libuv::Pipe do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.pipe
		@client = @loop.pipe
		@timeout = @loop.timer
		@timeout.start(5000) do
			@loop.stop
			@general_failure << "test timed out"
		end

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
		end
	end
	
	describe 'bidirectional inter process communication' do
		it "should send a ping and return a pong" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					p "Log called: #{level}: #{errorid}\n#{e.message}\n#{e.backtrace.join("\n")}\n"
				end


				binding = @server.bind("/tmp/ipc-example102.ipc")

				# catch server errors
				binding.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop

					p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
				end

				# consume data as it is recieved
				binding.progress do |server|
					server.accept.then do |client|
						client[:binding].progress do |data|
							@log << data
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
				cbinding = @client.connect("/tmp/ipc-example102.ipc") do |client|
					cbinding.progress do |data|
						@log << data

						@client.shutdown
						@server.close
					end

					@client.start_read
					@client.write('ping')
				end

				# close the handle
				cbinding.finally do
					@client.close
					@loop.stop
				end
			}

			#File.unlink("/tmp/ipc-example102.ipc")
			@general_failure.should == []
			@log.should == ['ping', 'pong']
		end
	end

	describe 'unidirectional pipeline' do
		before :each do
			begin
				File.unlink("/tmp/exchange-pipe.pipe")
			rescue
			end
			system "/usr/bin/mkfifo", "/tmp/exchange-pipe.pipe"
		end

		after :each do
		#	File.unlink("/tmp/exchange-pipe.pipe")
		end

		it "should send work to a consumer" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					p "Log called: #{level}: #{errorid}\n#{e.message}\n#{e.backtrace.join("\n")}\n"
				end


				file1 = File.open("/tmp/exchange-pipe.pipe", File::RDWR|File::NONBLOCK)

				binding = @server.open(file1.fileno) do |server, binding|
					heartbeat = @loop.timer
					heartbeat.then(proc {
						heartbeat.start(0, 200) do
							server.write('workload')
						end
					}, proc {
						@general_failure << :timer_fail
					})
				end



				file2 = File.open("/tmp/exchange-pipe.pipe", File::RDWR|File::NONBLOCK)

				# connect client to server
				consumer = @client.open(file2.fileno) do |consumer, stream|
					stream.progress do |data|
						@log = data
					end

					@client.start_read
				end



				timeout = @loop.timer
				timeout.then(proc {
					timeout.start(1000) do
						@loop.stop
					end
				}, proc {
					@general_failure << :timeout_fail
				})


				# catch server errors
				binding.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop
				end
			}

			#File.unlink("/tmp/ipc-example102.ipc")
			@general_failure.should == []
			@log.should == 'workload'
		end
	end
end
