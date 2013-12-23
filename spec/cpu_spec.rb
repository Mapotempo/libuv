require 'libuv'


describe ::Libuv do	
	it "Should return the number of CPU cores on the platform" do
		count = Libuv.cpu_count

		expect(count != nil && count > 0).to eq(true)
	end
end
