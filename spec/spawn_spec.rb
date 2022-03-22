require 'mt-libuv'

describe MTLibuv::Spawn do
    describe 'basic spawn of external process' do
        it "should accept arguments and return an termination signal code" do
            @reactor = MTLibuv::Reactor.new
            @log = []
            @reactor.run { |reactor|
                begin
                    p = MTLibuv::Spawn.new(reactor, './spec/test.sh', args: ['arg1', 'arg2'], env: ['SOME_VAR=123'])
                    p.stdout.progress do |data|
                        @log << data
                    end
                    p.stdout.start_read
                    @log << p.value
                rescue => e
                    @log << e
                    @reactor.stop
                end
            }

            term_signal = @log.pop
            expect(term_signal).to be(0)

            expect(@log[0]).to eq("123\narg1\narg2\n")
        end

        it "should return termination signal if exit code was 0" do
            @reactor = MTLibuv::Reactor.new
            @log = []
            @reactor.run { |reactor|
                begin
                    p = MTLibuv::Spawn.new(reactor, './spec/test.sh', args: ['arg1', 'arg2'], env: ['SOME_VAR=123'])
                    p.kill
                    p.stdout.progress do |data|
                        @log << data
                    end
                    p.stdout.start_read
                    @log << p.value
                rescue => e
                    @log << e
                    @reactor.stop
                end
            }

            term_signal = @log.pop
            expect(term_signal).to be(2)
            expect(@log[0]).to be(nil)
        end

        it "should fail if exit code was not 0 and read output from stderr" do
            @reactor = MTLibuv::Reactor.new
            @log = []
            @reactor.run { |reactor|
                begin
                    p = MTLibuv::Spawn.new(reactor, './spec/test_fail.sh')
                    p.stderr.progress do |data|
                        @log << data
                    end
                    p.stderr.start_read
                    @log << p.value
                rescue => e
                    @log << e
                    @reactor.stop
                end
            }

            stderr = @log[0]
            e = @log[1]
            expect(e.class).to be(::MTLibuv::Error::ProcessExitCode)
            expect(e.exit_status).to be(1)
            expect(e.term_signal).to be(0)
            expect(stderr.length).to be > 0
        end

        it "should be interactive" do
            @reactor = MTLibuv::Reactor.new
            @log = []
            @reactor.run { |reactor|
                begin
                    p = MTLibuv::Spawn.new(reactor, './spec/test_read.sh')
                    p.stdout.progress do |data|
                        @log << data
                    end
                    p.stdout.start_read
                    p.stdin.write("2017\n")
                    @log << p.value
                rescue => e
                    @log << e
                    @reactor.stop
                end
            }

            term_signal = @log.pop
            expect(term_signal).to be(0)

            expect(@log[0]).to eq("you entered 2017 - sweet\n")
        end

        it "should support inheriting parent processes streams" do
            @reactor = MTLibuv::Reactor.new
            @log = []
            @reactor.run { |reactor|
                begin
                    p = MTLibuv::Spawn.new(reactor, './spec/test.sh', args: ['arg1', 'arg2'], env: ['SOME_VAR=123'], mode: :inherit)
                    @log << p.stdout
                    @log << p.value
                rescue => e
                    @log << e
                    @reactor.stop
                end
            }

            term_signal = @log.pop
            expect(term_signal).to be(0)
            expect(@log[0]).to be(nil)
        end
    end
end
