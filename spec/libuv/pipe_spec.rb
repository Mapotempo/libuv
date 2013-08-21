require 'libuv'


describe Libuv::Pipe do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.pipe
		@client = @loop.pipe
		@timeout = @loop.timer do
			@loop.stop
			@general_failure << "test timed out"
		end
		@timeout.start(5000)

		@pipefile = "/tmp/test-pipe.pipe"

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
		end

		begin
			File.unlink(@pipefile)
		rescue
		end
	end

	after :each do
		begin
			File.unlink(@pipefile)
		rescue
		end
	end
	
	describe 'bidirectional inter process communication' do

		it "should send a ping and return a pong" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					begin
						p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
					rescue Exception
						p 'error in logger'
					end
				end

				@server.bind("/tmp/ipc-example.ipc") do |connection|
					connection.accept do |client|
						client.progress do |data|
							@log << data
							client.write('pong')
						end
						client.start_read
					end
				end

				# catch server errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop

					p "Failed with: #{reason.message}\n#{reason.backtrace.join("\n")}\n"
				end

				# start listening
				@server.listen(1024)



				# connect client to server
				@client.connect("/tmp/ipc-example.ipc") do |client|
					@client.progress do |data|
						@log << data

						@client.close
					end

					@client.start_read
					@client.write('ping')
				end

				# Stop the loop once the client handle is closed
				@client.finally do
					@server.close
					@loop.stop
				end
			}

			@log.should == ['ping', 'pong']
			@general_failure.should == []
		end
	end

	describe 'unidirectional pipeline' do
		before :each do
			system "/usr/bin/mkfifo", @pipefile
		end

		it "should send work to a consumer" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					p "Log called: #{level}: #{errorid}\n#{e.message}\n#{e.backtrace.join("\n")}\n"
				end


				heartbeat = @loop.timer
				file1 = File.open(@pipefile, File::RDWR|File::NONBLOCK)
				@server.open(file1.fileno) do |server|
					heartbeat.progress  do
						@server.write('workload')
						nil
					end
					heartbeat.start(0, 200)
				end
				


				file2 = File.open(@pipefile, File::RDWR|File::NONBLOCK)
				# connect client to server
				@client.open(file2.fileno) do |consumer|
					consumer.progress do |data|
						@log = data
						nil
					end

					consumer.start_read
				end


				timeout = @loop.timer do
					@server.close
					@client.close
					timeout.close
					heartbeat.close
					@loop.stop
					nil
				end
				timeout.start(1000)
			}

			@log.should == 'workload'
			@general_failure.should == []
		end
	end
end
