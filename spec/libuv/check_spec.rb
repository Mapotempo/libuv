require 'spec_helper'

describe Libuv::Check do
  let(:handle_name) { :check }
  let(:loop) { double() }
  let(:pointer) { double() }
  let(:promise) { double() }
  subject { Libuv::Check.new(loop, pointer) }

  it_behaves_like 'a handle'

  describe "#start" do
    it "calls Libuv::Ext.check_start" do
      Libuv::Ext.should_receive(:check_start).with(pointer, subject.method(:on_check))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.start
    end
  end

  describe "#stop" do
    it "calls Libuv::Ext.check_stop" do
      Libuv::Ext.should_receive(:check_stop).with(pointer)

      subject.stop
    end
  end
end