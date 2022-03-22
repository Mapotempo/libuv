require 'mt-libuv'

describe MTLibuv::Accessors do
    describe 'basic usage' do
        it 'should work seamlessly with the default thread' do
            count = 0
            reactor do |reactor|
                reactor.timer {
                    count += 1
                    reactor.stop if count == 3
                }.start(50, 10)
            end

            expect(count).to eq(3)
        end

        it 'work simply with new threads' do
            count = 0
            sig = ConditionVariable.new
            mutex = Mutex.new
            mutex.synchronize {

                # This will run on a new thread
                MTLibuv::Reactor.new do |reactor|
                    reactor.timer {
                        count += 1

                        if count == 3
                            reactor.stop
                            mutex.synchronize {
                                sig.signal
                            }
                        end
                    }.start(50, 10)
                end

                sig.wait(mutex)
            }

            expect(count).to eq(3)
        end
    end
end
