require 'mt-libuv'


describe ::MTLibuv do	
	it "Should return the number of CPU cores on the platform" do
		count = MTLibuv.cpu_count

		expect(count != nil && count > 0).to eq(true)
	end
end
