Feature: customise your event loop

  Prepare and check watchers are usually (but not always) used in tandem: prepare watchers
  get invoked before the process blocks and check watchers afterwards.

  Scenario: prepare loop
    Given a file named "prepare_check_example.rb" with:
      """
      require 'libuv'

      loop = Libuv::Loop.default

      prepared = false
      checked  = false
      unless_error = proc { |error|
        loop.stop
        abort "the following error occurred '#{error.inspect}'"
      }

      prepare = loop.prepare
      prepare.start.then unless_error do
        puts "preparing"
        prepared = true
      end

      check = loop.check
      check.start.then unless_error do
        puts "checking"
        abort "not prepared" unless prepared
        checked = true
      end

      timer = loop.timer
      timer.start(0, 200) do |e|
        puts "running cycles"
      end

      stopper = loop.timer
      stopper.start(2000, 0) do |e|
        timer.close
        prepare.close
        check.close
        stopper.close
        loop.stop
      end

      loop.run

      abort "not checked" unless checked
      """
    When I run `ruby prepare_check_example.rb`
    Then the exit status should be 0