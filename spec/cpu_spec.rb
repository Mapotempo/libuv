require 'libuv'


describe ::Libuv do	
	it "Should return the number of CPU cores on the platform" do
		count = Libuv.cpu_count

		(count != nil && count > 0).should == true
	end
end
