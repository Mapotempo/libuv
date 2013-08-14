require 'spec_helper'

describe Libuv::Loop do
  let(:loop_pointer) { double() }

  describe ".default" do
    it "calls Libuv::Ext.loop_default internally" do
      Libuv::Ext.should_receive(:default_loop).once.and_return(loop_pointer)
      FFI::AutoPointer.should_receive(:new).once.with(loop_pointer, Libuv::Ext.method(:loop_delete))
      Libuv::Ext.should_receive(:loop_delete).once
      Libuv::Loop.default
    end
  end

  describe ".new" do
    it "calls Libuv::Ext.loop_new" do
      Libuv::Ext.should_receive(:loop_new).once.and_return(loop_pointer)
      FFI::AutoPointer.should_receive(:new).once.with(loop_pointer, Libuv::Ext.method(:loop_delete))
      Libuv::Ext.should_receive(:loop_delete).once
      Libuv::Loop.new
    end
  end

  subject do
    FFI::AutoPointer.should_receive(:new).once.with(loop_pointer, Libuv::Ext.method(:loop_delete)).and_return(loop_pointer)
    Libuv::Loop.create(loop_pointer)
  end

  describe "#run" do
    it "calls Libuv::Ext.run" do
      Libuv::Ext.should_receive(:run).with(loop_pointer, :UV_RUN_DEFAULT)

      subject.run
    end
  end

  describe "#update_time" do
    it "calls Libuv::Ext.update_time" do
      Libuv::Ext.should_receive(:update_time).with(loop_pointer)

      subject.update_time
    end
  end

  describe "#now" do
    let(:now) { Time.now }

    it "calls Libuv::Ext.now" do
      Libuv::Ext.should_receive(:now).with(loop_pointer).and_return(now)

      subject.now.should == now
    end
  end

  describe "#last_error" do
    let(:error) { double() }

    it "calls Libuv::Ext.last_error" do
      Libuv::Ext.should_receive(:err_name).with(error).and_return("EINVAL")
      Libuv::Ext.should_receive(:strerror).with(error).and_return("invalid argument")

      subject.lookup_error(error).should == Libuv::Error::EINVAL.new("invalid argument")
    end
  end

  describe "#timer" do
    let(:timer_pointer) { double() }
    let(:timer) { double() }

    it "calls Libuv::Ext.timer_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_timer).and_return(timer_pointer)
      Libuv::Ext.should_receive(:timer_init).with(loop_pointer, timer_pointer)
      Libuv::Timer.should_receive(:new).with(subject, timer_pointer).and_return(timer)

      subject.timer.should == timer
    end
  end

  describe "#tcp" do
    let(:tcp_pointer) { double() }
    let(:tcp) { double() }

    it "calls Libuv::Ext.tcp_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_tcp).and_return(tcp_pointer)
      Libuv::Ext.should_receive(:tcp_init).with(loop_pointer, tcp_pointer)
      Libuv::TCP.should_receive(:new).with(subject, tcp_pointer).and_return(tcp)

      subject.tcp.should == tcp
    end
  end

  describe "#tty" do
    let(:tty_pointer) { double() }
    let(:tty) { double() }
    let(:fileno) { 6555 }

    before(:each) do
      Libuv::Ext.should_receive(:create_handle).with(:uv_tty).and_return(tty_pointer)
      Libuv::TTY.should_receive(:new).with(subject, tty_pointer).and_return(tty)
    end

    context "readable" do
      it "calls Libuv::Ext.tty_init" do
        Libuv::Ext.should_receive(:tty_init).with(loop_pointer, tty_pointer, fileno, 1)

        subject.tty(fileno, true).should == tty
      end
    end

    context "not readable" do
      it "calls Libuv::Ext.tty_init" do
        Libuv::Ext.should_receive(:tty_init).with(loop_pointer, tty_pointer, fileno, 0)

        subject.tty(fileno, false).should == tty
      end
    end
  end

  describe "#pipe" do
    let(:pipe_pointer) { double() }
    let(:pipe) { double() }

    before(:each) do
      Libuv::Ext.should_receive(:create_handle).with(:uv_pipe).and_return(pipe_pointer)
      Libuv::Pipe.should_receive(:new).with(subject, pipe_pointer).and_return(pipe)
    end

    context "with ipc" do
      it "calls Libuv::Ext.pipe_init" do
        Libuv::Ext.should_receive(:pipe_init).with(loop_pointer, pipe_pointer, 0)

        subject.pipe.should == pipe
      end
    end

    context "without ipc" do
      it "calls Libuv::Ext.pipe_init" do
        Libuv::Ext.should_receive(:pipe_init).with(loop_pointer, pipe_pointer, 1)

        subject.pipe(true).should == pipe
      end
    end
  end

  describe "#prepare" do
    let(:prepare_pointer) { double() }
    let(:prepare) { double() }

    it "calls Libuv::Ext.prepare_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_prepare).and_return(prepare_pointer)
      Libuv::Ext.should_receive(:prepare_init).with(loop_pointer, prepare_pointer)
      Libuv::Prepare.should_receive(:new).with(subject, prepare_pointer).and_return(prepare)

      subject.prepare.should == prepare
    end
  end

  describe "#check" do
    let(:check_pointer) { double() }
    let(:check) { double() }

    it "calls Libuv::Ext.check_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_check).and_return(check_pointer)
      Libuv::Ext.should_receive(:check_init).with(loop_pointer, check_pointer)
      Libuv::Check.should_receive(:new).with(subject, check_pointer).and_return(check)

      subject.check.should == check
    end
  end

  describe "#idle" do
    let(:idle_pointer) { double() }
    let(:idle) { double() }

    it "calls Libuv::Ext.idle_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_idle).and_return(idle_pointer)
      Libuv::Ext.should_receive(:idle_init).with(loop_pointer, idle_pointer)
      Libuv::Idle.should_receive(:new).with(subject, idle_pointer).and_return(idle)

      subject.idle.should == idle
    end
  end

  describe "#async" do
    let(:async_pointer) { double() }
    let(:async_callback) { double() }
    let(:async) { double() }

    it "requires a block" do
      expect { subject.async }.to raise_error(ArgumentError)
    end

    it "calls Libuv::Ext.async_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_async).and_return(async_pointer)
      Libuv::Ext.should_receive(:async_init).with(loop_pointer, async_pointer, async_callback)
      Libuv::Async.should_receive(:new).with(subject, async_pointer).and_return(async)
      async.should_receive(:callback).once.with(:on_async).and_return(async_callback)

      handle = subject.async { |e| }
      handle.should == async
    end
  end

  describe "#fs" do
    let(:filesystem) { double() }

    it "instantiates Libuv::Filesystem" do
      Libuv::Filesystem.should_receive(:new).once.with(subject).and_return(filesystem)

      subject.fs.should == filesystem
    end
  end

  describe "#fs_event" do
    let(:filename) { '/path/to/watch' }
    let(:fs_event_pointer) { double() }
    let(:fs_event_callback) { double() }
    let(:fs_event) { double() }

    it "requires a block" do
      expect { subject.fs_event(filename) }.to raise_error(ArgumentError)
    end

    it "calls Libuv::Ext.fs_event_init" do
      Libuv::Ext.should_receive(:create_handle).with(:uv_async)
      #Libuv::Ext.should_receive(:fs_event_init).with(loop_pointer, fs_event_pointer, filename, fs_event_callback, 0)
      Libuv::Ext.should_receive(:create_handle).with(:uv_fs_event).and_return(fs_event_pointer)
      Libuv::Ext.should_receive(:fs_event_init).with(loop_pointer, fs_event_pointer, filename, fs_event_callback, 0)
      Libuv::FSEvent.should_receive(:new).with(subject, fs_event_pointer).and_return(fs_event)
      fs_event.should_receive(:callback).once.with(:on_fs_event).and_return(fs_event_callback)

      handle = subject.fs_event(filename) { |e, filename, type| }
      handle.should == fs_event
    end
  end
end
