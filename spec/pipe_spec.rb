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

		@pipefile = "/tmp/test-pipes.pipe"

		@loop.all(@server, @client, @timeout).catch do |reason|
			@general_failure << reason.inspect
			@general_failure << "Failed with: #{reason.message}\n#{reason.backtrace}\n"
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
						@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace}\n"
					rescue Exception
						@general_failure << 'error in logger'
					end
				end

				@server.bind(@pipefile) do |client|
					client.progress do |data|
						@log << data
						client.write('pong')
					end
					client.start_read
				end

				# catch server errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop

					@general_failure << "Failed with: #{reason.message}\n#{reason.backtrace}\n"
				end

				# start listening
				@server.listen(1024)



				# connect client to server
				@client.connect(@pipefile) do |client|
					@client.progress do |data|
						@log << data

						@client.close
					end

					@client.start_read
					@client.write('ping')
				end

				@client.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop

					@general_failure << "Failed with: #{reason.message}\n#{reason.backtrace}\n"
				end

				# Stop the loop once the client handle is closed
				@client.finally do
					@server.close
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(['ping', 'pong'])
		end
	end

	# This test won't pass on windows as pipes don't work like this on windows
	describe 'unidirectional pipeline', :unix_only => true do
		before :each do
			system "/usr/bin/mkfifo", @pipefile
		end

		it "should send work to a consumer" do
			@loop.run { |logger|
				logger.progress do |level, errorid, error|
					@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
				end


				heartbeat = @loop.timer
				@file1 = @loop.file(@pipefile, File::RDWR|File::NONBLOCK)
				@file1.progress do
					@server.open(@file1.fileno) do |server|
						heartbeat.progress  do
							@server.write('workload').catch do |err|
								@general_failure << err
							end
						end
						heartbeat.start(0, 200)
					end
				end
				@file1.catch do |e|
					@general_failure << "Log called: #{e.inspect} - #{e.message}\n"
				end

				@file2 = @loop.file(@pipefile, File::RDWR|File::NONBLOCK)
				@file2.progress do
					# connect client to server
					@client.open(@file2.fileno) do |consumer|
						consumer.progress do |data|
							@log = data
						end

						consumer.start_read
					end
				end


				timeout = @loop.timer do
					@server.close
					@client.close
					timeout.close
					heartbeat.close
					@loop.stop
				end
				timeout.start(1000)
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq('workload')
		end
	end
end
