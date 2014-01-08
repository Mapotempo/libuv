require 'libuv'
require 'thread'


describe Libuv::Filesystem do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.default
		@filesystem = @loop.filesystem
		@timeout = @loop.timer do
			@loop.stop
			@general_failure << "test timed out"
		end
		@timeout.start(4000)

		@logger = proc { |level, errorid, error|
			begin
				@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
			rescue Exception
				@general_failure << 'error in logger'
			end
		}

		@thefile = "test-file.txt"

		@loop.all(@filesystem, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end
	end
	
	describe 'directory navigation' do
		it "should list the contents of a folder" do
			@loop.run { |logger|
				logger.progress &@logger

				currentDir = Dir.pwd
				listing = @filesystem.readdir(currentDir)
				listing.then do |result|
					@log = result
				end
				listing.catch do |error|
					@general_failure << error
				end
				listing.finally do
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect((@log.length > 0)).to eq(true)
		end
	end

	describe 'file manipulation' do
		it "should create and write to a file" do
			@loop.run { |logger|
				logger.progress &@logger

				file = @loop.file(@thefile, File::CREAT|File::WRONLY)
				file.progress do 
					file.write('write some data to a file').then do
						file.chmod(777).then do
							file.close
							@loop.stop
							@log = :success
						end
					end
				end
				file.catch do |error|
					@general_failure << error
					file.close
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(:success)
		end

		it "should read from a file" do
			@loop.run { |logger|
				logger.progress &@logger

				file = @loop.file(@thefile, File::RDONLY)
				file.progress do 
					file.read(100).then do |result|
						file.close
						@loop.stop
						@log = result
					end
				end
				file.catch do |error|
					@general_failure << error
					file.close
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq('write some data to a file')
		end

		it "should delete a file" do
			@loop.run { |logger|
				logger.progress &@logger

				op = @loop.filesystem.unlink(@thefile)
				op.then do
					@loop.stop
					@log = :success
				end
				op.catch do |error|
					@general_failure << error
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(:success)
		end
	end

	describe 'file streaming' do
		it "should send a file over a stream", :network => true do
			@loop.run { |logger|
				logger.progress &@logger

				@server = @loop.tcp
				@client = @loop.tcp

				@server.bind('127.0.0.1', 34570) do |server|
					server.accept do |client|
						client.progress do |data|
							file = @loop.file('.rspec', File::RDONLY)
							file.progress do
								file.send_file(client).then(proc {
									file.close
									client.close
								}, proc { |error|
									@general_failure << error
								})
							end
							file.catch do |error|
								@general_failure << error.inspect
								file.close
								client.close
							end
						end
						client.start_read
						client.finally do
							@server.close
							@loop.stop
						end
					end
				end
				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop
				end
				# start listening
				@server.listen(5)


				# connect client to server
				@client.connect('127.0.0.1', 34570) do |client|
					client.progress do |data|
						@log << data
					end

					@client.start_read
					@client.write('send file')
				end
				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
					@server.close
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(["--format progress\n"])
		end

		it "should send a file as a HTTP chunked response", :network => true do
			@loop.run { |logger|
				logger.progress &@logger

				@server = @loop.tcp
				@client = @loop.tcp

				@server.bind('127.0.0.1', 34568) do |server|
					server.accept do |client|
						client.progress do |data|
							file = @loop.file('.rspec', File::RDONLY)
							file.progress do
								file.send_file(client, :http).then(proc {
									file.close
									client.close
								}, proc { |error|
									@general_failure << error
								})
							end
							file.catch do |error|
								@general_failure << error.inspect
								file.close
								client.close
							end
						end
						client.start_read
						client.finally do
							@server.close
							@loop.stop
						end
					end
				end
				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@loop.stop
				end
				# start listening
				@server.listen(5)


				# connect client to server
				@client.connect('127.0.0.1', 34568) do |client|
					client.progress do |data|
						@log << data
					end

					@client.start_read
					@client.write('send file')
				end
				# catch errors
				@client.catch do |reason|
					@general_failure << reason.inspect
					@server.close
					@loop.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(["12\r\n--format progress\n\r\n", "0\r\n\r\n"])
		end
	end
end
