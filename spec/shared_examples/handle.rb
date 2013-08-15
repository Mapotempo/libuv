require 'spec_helper'

shared_examples_for 'a handle' do
  let(:deferred) { double() }

  describe "#ref" do
    it "calls Libuv::Ext.ref" do
      Libuv::Ext.should_receive(:ref).with(pointer)

      subject.ref
    end
  end

  describe "#unref" do
    it "calls Libuv::Ext.unref" do
      Libuv::Ext.should_receive(:unref).with(pointer)

      subject.unref
    end
  end

  describe "#close" do
    it "calls Libuv::Ext.close" do
      ::Libuv::Ext.should_receive(:close).once.with(pointer, subject.method(:on_close))
      loop.should_receive(:defer).once.and_return(deferred)
      deferred.should_receive(:promise).once
      subject.close
    end
  end

  describe "#active?" do
    it "is true for positive integers" do
      Libuv::Ext.should_receive(:is_active).with(pointer).and_return(2)
      subject.active?.should be_true
    end

    it "is false for integers less than 1" do
      Libuv::Ext.should_receive(:is_active).with(pointer).and_return(0)
      subject.active?.should be_false
    end
  end

  describe "#closing?" do
    it "is true for positive integers" do
      Libuv::Ext.should_receive(:is_closing).with(pointer).and_return(1)
      subject.closing?.should be_true
    end

    it "is false for integers less than 1" do
      Libuv::Ext.should_receive(:is_closing).with(pointer).and_return(-1)
      subject.closing?.should be_false
    end
  end
end