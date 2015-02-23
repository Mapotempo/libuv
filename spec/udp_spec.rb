require 'libuv'
require 'thread'


describe Libuv::UDP do
	before :each do
		@log = []
		@general_failure = []

		@loop = Libuv::Loop.new
		@server = @loop.udp
		@client = @loop.udp
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
						@general_failure << "Log called: #{level}: #{errorid}\n#{error.message}\n#{error.backtrace.join("\n") if error.backtrace}\n"
					rescue Exception => e
						@general_failure << "error in logger #{e.inspect}"
					end
				end


				@server.bind('127.0.0.1', 34567)
				@server.progress do |data, ip, port, server|
					@log << data
					server.send(ip, port, 'pong')
				end
				@server.start_read

				# catch errors
				@server.catch do |reason|
					@general_failure << reason.inspect
				end


				# connect client to server
				@client.bind('127.0.0.1', 34568)
				@client.progress do |data, ip, port, client|
					@log << data
					client.close
				end
				@client.start_read
				@client.send('127.0.0.1', 34567, 'ping')

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

			expect(@log).to eq(['ping', 'pong'])
			expect(@general_failure).to eq([])
		end
	end
end
