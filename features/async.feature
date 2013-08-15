Feature: wake up another event loop

  Libuv::Loop cannot be shared by multiple threads. To wake up a control loop in a different
  thread, use Libuv::Loop#async, which is thread safe

  Scenario: wake up an event loop from a different thread
    Given a file named "async_example.rb" with:
      """
      require 'libuv'

      count = 0
      loop  = Libuv::Loop.default

      timer = loop.timer
      timer.start(0, 100) do |e|
        count += 1
        sleep(0.2)
      end

      callback = loop.async do |e|
        stopper = loop.timer
        stopper.start(1000, 0) do |e|
          timer.close
          callback.close
          stopper.close
          loop.stop
        end
      end

      loop.work do
        callback.call
      end

      loop.run

      abort "failure, count is #{count}" if count >= 11
      """
    When I run `ruby async_example.rb`
    Then the exit status should be 0