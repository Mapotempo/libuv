require 'spec_helper'

describe Libuv::Filesystem do
  let(:loop) { double() }
  let(:loop_pointer) { double() }
  let(:promise) { double() }
  subject { Libuv::Filesystem.new(loop) }

  before(:each) do
    loop.stub(:to_ptr) { loop_pointer }
  end

  describe "#open" do
    let(:path) { "/tmp/file" }
    let(:mode) { 0755 }
    let(:flags) { File::CREAT | File::EXCL | File::APPEND }
    let(:open_request) { double() }

    it "calls Libuv::Ext.fs_open" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(open_request)
      Libuv::Ext.should_receive(:fs_open).with(loop_pointer, open_request, path, flags, mode, subject.method(:on_open))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.open(path, flags, mode)
    end
  end

  describe "#unlink" do
    let(:path) { "/tmp/file" }
    let(:unlink_request) { double() }

    it "calls Libuv::Ext.fs_unlink" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(unlink_request)
      Libuv::Ext.should_receive(:fs_unlink).with(loop_pointer, unlink_request, path, subject.method(:on_unlink))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.unlink(path)
    end
  end

  describe "#mkdir" do
    let(:path) { "/tmp/dir" }
    let(:mode) { 0777 }
    let(:mkdir_request) { double() }

    it "calls Libuv::Ext.fs_mkdir" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(mkdir_request)
      Libuv::Ext.should_receive(:fs_mkdir).with(loop_pointer, mkdir_request, path, mode, subject.method(:on_mkdir))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.mkdir(path, mode)
    end
  end

  describe "#rmdir" do
    let(:path) { "/tmp/dir" }
    let(:rmdir_request) { double() }

    it "calls Libuv::Ext.fs_rmdir" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(rmdir_request)
      Libuv::Ext.should_receive(:fs_rmdir).with(loop_pointer, rmdir_request, path, subject.method(:on_rmdir))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.rmdir(path)
    end
  end

  describe "#readdir" do
    let(:path) { '/tmp' }
    let(:readdir_request) { double() }

    it "calls Libuv::Ext.fs_readdir" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(readdir_request)
      Libuv::Ext.should_receive(:fs_readdir).with(loop_pointer, readdir_request, path, 0, subject.method(:on_readdir))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.readdir(path)
    end
  end

  describe "#stat" do
    let(:path) { '/tmp/filename' }
    let(:stat_request) { double() }

    it "calls Libuv::Ext.fs_stat" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(stat_request)
      Libuv::Ext.should_receive(:fs_stat).with(loop_pointer, stat_request, path, subject.method(:on_stat))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.stat(path)
    end
  end

  describe "#rename" do
    let(:old_path) { '/tmp/old_file' }
    let(:new_path) { '/tmp/new_file' }
    let(:rename_request) { double() }

    it "calls Libuv::Ext.fs_rename" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(rename_request)
      Libuv::Ext.should_receive(:fs_rename).with(loop_pointer, rename_request, old_path, new_path, subject.method(:on_rename))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.rename(old_path, new_path)
    end
  end

  describe "#chmod" do
    let(:path) { '/tmp/somepath' }
    let(:mode) { 0755 }
    let(:chmod_request) { double() }

    it "calls Libuv::Ext.fs_chmod" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(chmod_request)
      Libuv::Ext.should_receive(:fs_chmod).with(loop_pointer, chmod_request, path, mode, subject.method(:on_chmod))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.chmod(path, mode)
    end
  end

  describe "#utime" do
    let(:path) { '/tmp/filename' }
    let(:atime) { 1291404900 } # 2010-12-03 20:35:00
    let(:mtime) { 400497753 }  # 1982-09-10 11:22:33
    let(:utime_request) { double() }

    it "calls Libuv::Ext.fs_utime" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(utime_request)
      Libuv::Ext.should_receive(:fs_utime).with(loop_pointer, utime_request, path, atime, mtime, subject.method(:on_utime))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.utime(path, atime, mtime)
    end
  end

  describe "#lstat" do
    let(:path) { '/tmp/filename' }
    let(:lstat_request) { double() }

    it "calls Libuv::Ext.fs_lstat" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(lstat_request)
      Libuv::Ext.should_receive(:fs_lstat).with(loop_pointer, lstat_request, path, subject.method(:on_lstat))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.lstat(path)
    end
  end

  describe "#link" do
    let(:old_path) { '/tmp/old_file' }
    let(:new_path) { '/tmp/new_file' }
    let(:link_request) { double() }

    it "calls Libuv::Ext.fs_link" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(link_request)
      Libuv::Ext.should_receive(:fs_link).with(loop_pointer, link_request, old_path, new_path, subject.method(:on_link))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.link(old_path, new_path)
    end
  end

  describe "#symlink" do
    let(:old_path) { '/tmp/old_file' }
    let(:new_path) { '/tmp/new_file' }
    let(:symlink_request) { double() }

    it "calls Libuv::Ext.fs_link" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(symlink_request)
      Libuv::Ext.should_receive(:fs_symlink).with(loop_pointer, symlink_request, old_path, new_path, 0, subject.method(:on_symlink))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.symlink(old_path, new_path)
    end
  end

  describe "#readlink" do
    let(:path) { '/tmp/symlink' }
    let(:readlink_request) { double() }

    it "calls Libuv::Ext.fs_readlink" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(readlink_request)
      Libuv::Ext.should_receive(:fs_readlink).with(loop_pointer, readlink_request, path, subject.method(:on_readlink))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.readlink(path)
    end
  end

  describe "#chown" do
    let(:path) { '/tmp/chownable_file' }
    let(:uid) { 0 }
    let(:gid) { 0 }
    let(:chown_request) { double() }

    it "calls Libuv::Ext.fs_chown" do
      Libuv::Ext.should_receive(:create_request).with(:uv_fs).and_return(chown_request)
      Libuv::Ext.should_receive(:fs_chown).with(loop_pointer, chown_request, path, uid, gid, subject.method(:on_chown))
      loop.should_receive(:defer).once.and_return(promise)
      promise.should_receive(:promise).once

      subject.chown(path, uid, gid)
    end
  end
end