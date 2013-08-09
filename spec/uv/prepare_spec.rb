require 'spec_helper'

describe Libuv::Prepare do
  let(:handle_name) { :prepare }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::Prepare.new(loop, pointer) }

  it_behaves_like 'a handle'

  describe "#start" do
    it "calls Libuv::Ext.prepare_start" do
      Libuv::Ext.should_receive(:prepare_start).with(pointer, subject.method(:on_prepare))

      subject.start
    end
  end

  describe "#stop" do
    it "calls Libuv::Ext.prepare_stop" do
      Libuv::Ext.should_receive(:prepare_stop).with(pointer)

      subject.stop
    end
  end
end