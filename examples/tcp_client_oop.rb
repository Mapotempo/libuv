require 'rubygems'
require 'bundler/setup'
require 'libuv'

loop = Libuv::Loop.default

client = loop.tcp
unless_error = proc { |err|
  p err
  exit 1
}

client.connect("127.0.0.1", 10000).then unless_error do
  client.write("GET /\r\nHost: localhost:10000\r\nAccept: *\r\n\r\n\n").then unless_error do
    client.start_read do |data, err|
      if err
        p err
        exit 1
      end
      puts data
      client.close
      loop.stop
    end
  end
  # client.close
end

loop.run