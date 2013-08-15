require 'rubygems'
require 'bundler/setup'
require 'libuv'

loop = Libuv::Loop.default

server = loop.tcp
server.bind("0.0.0.0", 10000)
unless_error = proc { |err| p err }

server.listen(128).then unless_error do
  client = server.accept

  client.start_read do |err, data|
    puts data
    if err
      p err
      client.close
    end
    client.stop_read
    client.write("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nhello world\n").then unless_error do
      if err
        p err
      end
      client.close
    end
  end
end

stoper = loop.timer
stoper.start(50000, 0) do |e|
  puts "50 seconds passed"
  server.close
  stoper.close
  loop.stop
  if e
    raise e
  end
end

loop.run
