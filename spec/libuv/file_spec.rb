require 'spec_helper'

describe Libuv::File do
  let(:loop) { double() }
  let(:loop_pointer) { double() }
  let(:fd) { rand(6555) }
  let(:promise) { double() }
  subject { Libuv::File.new(loop, fd) }

  before(:each) do
    loop.stub(:to_ptr) { loop_pointer }
  end

  describe "#close" do
    let(:close_request) { double() }

    it "calls Libuv::Ext.fs_close" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(close_request)
      Libuv::Ext.should_receive(:fs_close).with(loop_pointer, close_request, fd, subject.method(:on_close))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.close
    end
  end

  describe "#read" do
    let(:read_request) { double() }
    let(:length) { 1024 }
    let(:read_buffer) { double() }
    let(:offset) { 0 }

    it "calls Libuv::Ext.fs_read" do
      FFI::MemoryPointer.should_receive(:new).with(length).and_return(read_buffer)
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(read_request)
      Libuv::Ext.should_receive(:fs_read).with(loop_pointer, read_request, fd, read_buffer, length, offset, subject.method(:on_read))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.read(length, offset)
    end
  end

  describe "#write" do
    let(:offset) { 0 }
    let(:data) { "some payload" }
    let(:write_buffer_length) { data.size }
    let(:write_buffer) { double() }
    let(:write_request) { double() }

    it "calls Libuv::Ext.fs_write" do
      FFI::MemoryPointer.should_receive(:from_string).with(data).and_return(write_buffer)
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(write_request)
      Libuv::Ext.should_receive(:fs_write).with(loop_pointer, write_request, fd, write_buffer, write_buffer_length, offset, subject.method(:on_write))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.write(data, offset)
    end
  end

  describe "#stat" do
    let(:stat_request) { double() }

    it "calls Libuv::Ext.fs_fstat" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(stat_request)
      Libuv::Ext.should_receive(:fs_fstat).with(loop_pointer, stat_request, fd, subject.method(:on_stat))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.stat
    end
  end

  describe "#sync" do
    let(:sync_request) { double() }

    it "calls Libuv::Ext.fs_fsync" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(sync_request)
      Libuv::Ext.should_receive(:fs_fsync).with(loop_pointer, sync_request, fd, subject.method(:on_sync))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.sync
    end
  end

  describe "#datasync" do
    let(:datasync_request) { double() }

    it "calls Libuv::Ext.fs_fdatasync" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(datasync_request)
      Libuv::Ext.should_receive(:fs_fdatasync).with(loop_pointer, datasync_request, fd, subject.method(:on_datasync))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.datasync
    end
  end

  describe "#truncate" do
    let(:offset) { 0 }
    let(:truncate_request) { double() }

    it "calls Libuv::Ext.fs_ftruncate" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(truncate_request)
      Libuv::Ext.should_receive(:fs_ftruncate).with(loop_pointer, truncate_request, fd, offset, subject.method(:on_truncate))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.truncate(offset)
    end
  end

  describe "#utime" do
    let(:atime) { 1291404900 } # 2010-12-03 20:35:00
    let(:mtime) { 400497753 }  # 1982-09-10 11:22:33
    let(:utime_request) { double() }

    it "calls Libuv::Ext.fs_futime" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(utime_request)
      Libuv::Ext.should_receive(:fs_futime).with(loop_pointer, utime_request, fd, atime, mtime, subject.method(:on_utime))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.utime(atime, mtime)
    end
  end

  describe "#chmod" do
    let(:mode) { 0755 }
    let(:chmod_request) { double() }

    it "calls Libuv::Ext.fs_fchmod" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(chmod_request)
      Libuv::Ext.should_receive(:fs_fchmod).with(loop_pointer, chmod_request, fd, mode, subject.method(:on_chmod))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.chmod(mode)
    end
  end

  describe "#chown" do
    let(:uid) { 0 }
    let(:gid) { 0 }
    let(:chown_request) { double() }

    it "calls Libuv::Ext.fs_fchown" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(chown_request)
      Libuv::Ext.should_receive(:fs_fchown).with(loop_pointer, chown_request, fd, uid, gid, subject.method(:on_chown))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.chown(uid, gid)
    end
  end
end