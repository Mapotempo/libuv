Feature: Named pipes

  Unix domain sockets and named pipes are useful for inter-process communication.

  Scenario: bidirectional inter process communication
    Given a file named "ipc_server_example.rb" with:
      """
      require 'libuv'

      pong = "pong"
      loop = Libuv::Loop.default

      server  = loop.pipe
      unless_error = proc { |error|
        loop.stop
        abort "the following error occurred '#{error}'"
      }

      server.bind("/tmp/ipc-example.ipc")
      server.listen(128).then unless_error do
        client = server.accept

        client.start_read do |e, data|
          unless_error.call(e) if e

          client.write(pong).then unless_error do
            client.close
            server.close
            loop.stop
          end
        end
      end

      stopper = loop.timer
  
      stopper.start(5000, 0) do |e|
        unless_error.call(e) if e
  
        server.close
        stopper.close
        loop.stop
      end

      loop.run
      """
    And a file named "ipc_client_example.rb" with:
      """
      require 'libuv'

      ping = "ping"
      loop = Libuv::Loop.default

      client = loop.pipe
      unless_error = proc { |error|
        loop.stop
        abort "the following error occurred '#{error}'"
      }

      client.connect("/tmp/ipc-example.ipc").then unless_error do
        client.start_read do |e, pong|
          unless_error.call(e) if e

          puts "received #{pong} from server"

          client.close
          loop.stop
        end

        client.write(ping).then unless_error do
          puts "sent #{ping} to server"
        end
      end

      loop.run
      """
    When I run `ruby ipc_server_example.rb` interactively
    And I wait for 1 seconds
    And I run `ruby ipc_client_example.rb`
    Then the output should contain ping pong exchange

  Scenario: unidirectional pipeline
    Given a named pipe "/tmp/exchange-pipe.pipe"
    And a file named "pipe_producer_example.rb" with:
      """
      require 'libuv'
      loop = Libuv::Loop.default
  
      pipe     = File.open("/tmp/exchange-pipe.pipe", File::RDWR|File::NONBLOCK)
      producer = loop.pipe
  
      producer.open(pipe.fileno)
  
      heartbeat = loop.timer
  
      heartbeat.start(0, 200) do |e|
        raise e if e
  
        producer.write("workload") { |e| raise e if e }
      end
  
      stopper = loop.timer
  
      stopper.start(3000, 0) do |e|
        raise e if e
  
        heartbeat.close
        producer.close
        stopper.close
        loop.stop
      end
  
      loop.run
      """
    And a file named "pipe_consumer_example.rb" with:
      """
      require 'libuv'
      loop = Libuv::Loop.default
  
      pipe     = File.open("/tmp/exchange-pipe.pipe", File::RDWR|File::NONBLOCK)
      consumer = loop.pipe
  
      consumer.open(pipe.fileno)
  
      consumer.start_read do |e, workload|
        raise e if e
  
        puts "received #{workload}"
      end
  
      stopper = loop.timer
  
      stopper.start(2000, 0) do |e|
        raise e if e
  
        consumer.close
        stopper.close
        loop.stop
      end
  
      loop.run
      """
    When I run `ruby pipe_producer_example.rb` interactively
    And I run `ruby pipe_consumer_example.rb`
    Then the output should contain consumed workload