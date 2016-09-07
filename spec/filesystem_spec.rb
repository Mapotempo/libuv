require 'libuv'
require 'thread'


describe Libuv::Filesystem do
	before :each do
		@log = []
		@general_failure = []

		@reactor = Libuv::Reactor.default
		@filesystem = @reactor.filesystem
		@timeout = @reactor.timer do
			@reactor.stop
			@general_failure << "test timed out"
		end
		@timeout.start(4000)

		@reactor.notifier do |error, context|
			begin
				@general_failure << "Log called: #{context}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
			rescue Exception => e
				@general_failure << "error in logger #{e.inspect}"
			end
		end

		@thefile = "test-file.txt"

		@reactor.all(@filesystem, @timeout).catch do |reason|
			@general_failure << reason.inspect
		end
	end
	
	describe 'directory navigation' do
		it "should list the contents of a folder" do
			@reactor.run { |reactor|
				currentDir = Dir.pwd
				listing = @filesystem.readdir(currentDir, wait: false)
				listing.then do |result|
					@log = result
				end
				listing.catch do |error|
					@general_failure << error
				end
				listing.finally do
					@timeout.close
					@reactor.stop
				end
			}

			expect(@general_failure).to eq([])
			expect((@log.length > 0)).to eq(true)
		end
	end

	describe 'file manipulation' do
		it "should create and write to a file" do
			@reactor.run { |reactor|
				file = @reactor.file(@thefile, File::CREAT|File::WRONLY)
				begin
					file.write('write some data to a file')
					file.chmod(777)
					@timeout.close
					@reactor.stop
					@log = :success
				rescue => error
					@general_failure << error
					@timeout.close
					@reactor.stop
				ensure
					file.close
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(:success)
		end

		it "should return stats on the file" do
			@reactor.run { |reactor|
				file = @reactor.file(@thefile, File::RDONLY)
				begin
					stats = file.stat
					@timeout.close
					@reactor.stop
					@log << stats[:st_mtim][:tv_sec]
				rescue => error
					@general_failure << error
					@timeout.close
					@reactor.stop
				ensure
					file.close
				end
			}

			expect(@general_failure).to eq([])
			expect(@log[0]).to be_kind_of(Integer)
			expect(@log.length).to eql(1)
		end

		it "should read from a file" do
			@reactor.run { |reactor|
				file = @reactor.file(@thefile, File::RDONLY)
				begin
					result = file.read(100)
					@timeout.close
					@reactor.stop
					@log = result
				rescue => error
					@general_failure << error
					@timeout.close
					file.close
					@reactor.stop
				ensure
					file.close
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq('write some data to a file')
		end

		it "should delete a file" do
			@reactor.run { |reactor|
				op = @reactor.filesystem.unlink(@thefile, wait: false)
				op.then do
					@timeout.close
					@reactor.stop
					@log = :success
				end
				op.catch do |error|
					@general_failure << error
					@timeout.close
					@reactor.stop
				end
			}

			expect(@general_failure).to eq([])
			expect(@log).to eq(:success)
		end
	end

	describe 'file streaming' do
		it "should send a file over a stream", :network => true do
			@reactor.run { |reactor|
				@server = @reactor.tcp
				@client = @reactor.tcp

				@server.bind('127.0.0.1', 34570) do |client|
					client.progress do |data|
						file = @reactor.file('.rspec', File::RDONLY) do
							file.send_file(client, wait: false).then(proc {
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
						@timeout.close
						@server.close
						@reactor.stop
					end
				end
				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@reactor.stop
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
					@reactor.stop
				end
			}

			expect(@general_failure).to eq([])
			# Windows GIT adds the carriage return
			if FFI::Platform.windows?
				expect(@log).to eq(["--format progress\r\n"])
			else
				expect(@log).to eq(["--format progress\n"])
			end
		end

		it "should send a file as a HTTP chunked response", :network => true do
			@reactor.run { |reactor|
				@server = @reactor.tcp
				@client = @reactor.tcp

				@server.bind('127.0.0.1', 34568) do |client|
					client.progress do |data|
						file = @reactor.file('.rspec', File::RDONLY) do
							file.send_file(client, using: :http, wait: false).then(proc {
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
						@timeout.close
						@server.close
						@reactor.stop
					end
				end
				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
					@reactor.stop
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
					@reactor.stop
				end
			}

			expect(@general_failure).to eq([])

			# Windows GIT adds the carriage return
			if FFI::Platform.windows?
				expect(@log.join('')).to eq("13\r\n--format progress\r\n\r\n0\r\n\r\n")
			else
				expect(@log.join('')).to eq("12\r\n--format progress\n\r\n0\r\n\r\n")
			end
		end
	end
end
