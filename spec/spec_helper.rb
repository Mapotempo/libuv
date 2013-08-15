require 'libuv'

module UVHelper
    def new_tcp
        default_loop.tcp
    end

    def default_loop
        ::Libuv::Loop.default
    end

    def run_loop
        default_loop.run
    end

    def run_loop_once
        default_loop.run(:UV_RUN_ONCE)
    end
end

RSpec.configure do |c|
    c.include UVHelper
end

require_relative 'shared_examples/handle'
require_relative 'shared_examples/stream'
