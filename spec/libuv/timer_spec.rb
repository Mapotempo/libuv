require 'spec_helper'

describe Libuv::Timer do
  let(:handle_name) { :timer }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::Timer.new(loop, pointer) }

  it_behaves_like 'a handle'

  describe "#start" do
    let(:timeout) { 50000 }
    let(:repeat) { 50000 }

    it "requires a block" do
      expect { subject.start(timeout, repeat) }.to raise_error(ArgumentError)
    end

    it "calls Libuv::Ext.timer_start" do
      Libuv::Ext.should_receive(:timer_start).with(pointer, subject.method(:on_timer), timeout, repeat)

      subject.start(timeout, repeat) { |e| }
    end
  end

  describe "#stop" do
    it "calls Libuv::Ext.timer_stop" do
      Libuv::Ext.should_receive(:timer_stop).with(pointer)

      subject.stop
    end
  end

  describe "#again" do
    it "calls Libuv::Ext.timer_again" do
      Libuv::Ext.should_receive(:timer_again).with(pointer)

      subject.again
    end
  end

  describe "#repeat=" do
    let(:repeat) { 50000 }

    it "calls Libuv::Ext.timer_set_repeat" do
      Libuv::Ext.should_receive(:timer_set_repeat).with(pointer, repeat)

      subject.repeat = repeat
    end
  end

  describe "#repeat" do
    let(:repeat) { 50000 }

    it "calls Libuv::Ext.timer_get_repeat" do
      Libuv::Ext.should_receive(:timer_get_repeat).with(pointer).and_return(repeat)

      subject.repeat.should == repeat
    end
  end
end