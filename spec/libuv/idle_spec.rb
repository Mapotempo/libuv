require 'spec_helper'

describe Libuv::Idle do
  let(:handle_name) { :idle }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::Idle.new(loop, pointer) }

  it_behaves_like 'a handle'

  describe "#start" do
    it "requires a block" do
      expect { subject.start }.to raise_error(ArgumentError)
    end

    it "calls Libuv::Ext.idle_start" do
      Libuv::Ext.should_receive(:idle_start).with(pointer, subject.method(:on_idle))

      subject.start { |e| }
    end
  end

  describe "#stop" do
    it "calls Libuv::Ext.idle_stop" do
      Libuv::Ext.should_receive(:idle_stop).with(pointer)

      subject.stop
    end
  end
end