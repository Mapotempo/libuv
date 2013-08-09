require 'spec_helper'

describe Libuv::TCP do
  let(:handle_name) { :tcp }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::TCP.new(loop, pointer) }

  it_behaves_like 'a handle'
  it_behaves_like 'a stream'

  describe "#bind" do
    let(:ip_addr) { double() }
    let(:port) { 0 }

    context "ipv4" do
      let(:ip) { "0.0.0.0" }

      it "calls Libuv::Ext.tcp_bind" do
        Libuv::Ext.should_receive(:ip4_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:tcp_bind).with(pointer, ip_addr)

        subject.bind(ip, port)
      end
    end

    context "ipv6" do
      let(:ip) { "::" }

      it "calls Libuv::Ext.tcp_bind6" do
        Libuv::Ext.should_receive(:ip6_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:tcp_bind6).with(pointer, ip_addr)

        subject.bind(ip, port)
      end
    end
  end

  describe "#connect" do
    let(:connect_request) { double() }
    let(:ip_addr) { double() }
    let(:port) { 0 }

    context "ipv4" do
      let(:ip) { "0.0.0.0" }

      it "calls Libuv::Ext.tcp_connect" do
        Libuv::Ext.should_receive(:create_request).with(:uv_connect).and_return(connect_request)
        Libuv::Ext.should_receive(:ip4_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:tcp_connect).with(connect_request, pointer, ip_addr, subject.method(:on_connect))

        subject.connect(ip, port) { |e| }
      end
    end

    context "ipv6" do
      let(:ip) { "::" }

      it "calls Libuv::Ext.tcp_connect6" do
        Libuv::Ext.should_receive(:create_request).with(:uv_connect).and_return(connect_request)
        Libuv::Ext.should_receive(:ip6_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:tcp_connect6).with(connect_request, pointer, ip_addr, subject.method(:on_connect))

        subject.connect(ip, port) { |e| }
      end
    end
  end

  # describe "#sockname" do
  #   let(:sockaddr) { double() }
  #   let(:len) { 15 }
  # 
  #   it "calls Libuv::Ext.tcp_getsockname" do
  #     Libuv::Ext.should_receive(:tcp_getsockname).with(pointer, sockaddr, len)
  #   end
  # end
  # 
  # describe "#peername" do
  # end

  describe "#enable_nodelay" do
    it "calls Libuv::Ext.tcp_nodelay" do
      Libuv::Ext.should_receive(:tcp_nodelay).with(pointer, 1)

      subject.enable_nodelay
    end
  end

  describe "#disable_nodelay" do
    it "calls Libuv::Ext.tcp_nodelay" do
      Libuv::Ext.should_receive(:tcp_nodelay).with(pointer, 0)

      subject.disable_nodelay
    end
  end

  describe "#enable_keepalive" do
    let(:keepalive_delay) { 150 }

    it "calls Libuv::Ext.tcp_keepalive" do
      Libuv::Ext.should_receive(:tcp_keepalive).with(pointer, 1, keepalive_delay)

      subject.enable_keepalive(keepalive_delay)
    end
  end

  describe "#disable_keepalive" do
    it "calls Libuv::Ext.tcp_keepalive" do
      Libuv::Ext.should_receive(:tcp_keepalive).with(pointer, 0, 0)

      subject.disable_keepalive
    end
  end

  describe "#enable_simultaneous_accepts" do
    it "calls Libuv::Ext.tcp_simultaneous_accepts" do
      Libuv::Ext.should_receive(:tcp_simultaneous_accepts).with(pointer, 1)

      subject.enable_simultaneous_accepts
    end
  end

  describe "#disable_simultaneous_accepts" do
    it "calls Libuv::Ext.tcp_simultaneous_accepts" do
      Libuv::Ext.should_receive(:tcp_simultaneous_accepts).with(pointer, 0)

      subject.disable_simultaneous_accepts
    end
  end
end