require 'spec_helper'

describe Libuv::Pipe do
  let(:handle_name) { :pipe }
  let(:loop) { double() }
  let(:pointer) { double() }
  let(:promise) { double() }
  subject { Libuv::Pipe.new(loop, pointer) }

  it_behaves_like 'a handle'
  it_behaves_like 'a stream'

  describe "#open" do
    let(:fileno) { 6555 }

    it "calls Libuv::Ext.pipe_open" do
      Libuv::Ext.should_receive(:pipe_open).with(pointer, fileno)

      subject.open(fileno)
    end
  end

  describe "#bind" do
    let(:name) {
      name = "/tmp/filename.ipc"
      name = subject.send :windows_path, name if FFI::Platform.windows?
      name
    }

    it "calls Libuv::Ext.pipe_bind" do
      Libuv::Ext.should_receive(:pipe_bind).with(pointer, name)

      subject.bind(name)
    end
  end

  describe "#connect" do
    let(:name) {
      name = "/tmp/filename.ipc"
      name = subject.send :windows_path, name if FFI::Platform.windows?
      name
    }
    let(:connect_request) { double() }

    it "calls Libuv::Ext.pipe_connect" do
      Libuv::Ext.should_receive(:create_request).with(:uv_connect).and_return(connect_request)
      Libuv::Ext.should_receive(:pipe_connect).with(connect_request, pointer, name, subject.method(:on_connect))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.connect(name)
    end
  end

  describe "#pending_instances=" do
    it "calls Libuv::Ext.pipe_pending_instances" do
      Libuv::Ext.should_receive(:pipe_pending_instances).with(pointer, 5)
      subject.pending_instances = 5
    end
  end
end