require 'libuv'

describe Libuv::Timer do
	describe 'setting properties' do
		it "should allow repeat to be set" do
      @reactor = Libuv::Reactor.new
			@reactor.run { |logger|
        @timer = @reactor.timer
        @timer.repeat = 5
        expect(@timer.repeat).to eq(5)
      }
    end
  end
end
