require 'libuv'
require 'thread'


describe Libuv::Filesystem do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@filesystem = @loop.filesystem
		@timeout = @loop.timer do
			@loop.stop
			@general_failure << "test timed out"
		end
		@timeout.start(4000)

		@logger = proc { |level, errorid, error|
			begin
				p "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n")}\n"
			rescue Exception
				p 'error in logger'
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

			@general_failure.should == []
			(@log.length > 0).should == true
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

			@general_failure.should == []
			@log.should == :success
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

			@general_failure.should == []
			@log.should == 'write some data to a file'
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

			@general_failure.should == []
			@log.should == :success
		end
	end
end
