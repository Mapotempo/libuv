# frozen_string_literal: true

module Libuv
    module Accessors
        def reactor
            thread = Libuv::Reactor.current
            if thread.nil?
                thread = Libuv::Reactor.default
                if thread.reactor_running?
                    raise 'No reactor available on this thread'
                end
            end
            thread.run { yield(thread) } if block_given?
            thread
        end

        Functions = [
            :defer, :all, :any, :finally, :update_time, :now, :lookup_error, :tcp,
            :udp, :tty, :pipe, :timer, :prepare, :check, :idle, :async, :signal,
            :work, :lookup, :fs_event, :file, :filesystem, :schedule, :next_tick,
            :stop, :reactor_thread?, :reactor_running?, :run
        ].freeze

        Functions.each do |function|
            define_method function do |*args|
                thread = Libuv::Reactor.current

                if thread
                    thread.send(function, *args)
                else
                    thread = Libuv::Reactor.default
                    if thread.reactor_running?
                        raise 'attempted Libuv::Reactor access on non-reactor thread'
                    else
                       thread.send(function, *args) 
                    end
                end
            end
        end
    end
end
