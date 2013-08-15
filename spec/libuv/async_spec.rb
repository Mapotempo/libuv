require 'spec_helper'

describe Libuv::Async do
  let(:handle_name) { :async }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::Async.new(loop, pointer) { |e| } }

  it_behaves_like 'a handle'

  describe "#call" do
    it "calls Libuv::Ext.async_send" do
      Libuv::Ext.should_receive(:async_send).with(pointer)

      subject.call
    end
  end
end