require 'spec_helper'

describe Libuv::UDP do
  let(:handle_name) { :udp }
  let(:loop) { double() }
  let(:pointer) { double() }
  let(:promise) { double() }
  subject { Libuv::UDP.new(loop, pointer) }

  it_behaves_like 'a handle'

  describe "#bind" do
    let(:ip_addr) { double() }
    let(:port) { 0 }

    context "ipv4" do
      let(:ip) { "0.0.0.0" }

      it "calls Libuv::Ext.udp_bind" do
        Libuv::Ext.should_receive(:ip4_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:udp_bind).with(pointer, ip_addr, 0)

        subject.bind(ip, port)
      end
    end

    context "ipv6" do
      let(:ip) { "::" }

      it "calls Libuv::Ext.udp_bind6" do
        Libuv::Ext.should_receive(:ip6_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:udp_bind6).with(pointer, ip_addr, 0)

        subject.bind(ip, port)
      end


      it "calls Libuv::Ext.udp_bind6 with ipv6_only" do
        Libuv::Ext.should_receive(:ip6_addr).with(ip, port).and_return(ip_addr)
        Libuv::Ext.should_receive(:udp_bind6).with(pointer, ip_addr, 1)

        subject.bind(ip, port, true)
      end
    end
  end

  # describe "#sockname" do
  # end

  describe "#join" do
    let(:multicast_address) { "239.255.0.1" }
    let(:interface_address) { "" }

    it "calls Libuv::Ext.udp_set_membership" do
      Libuv::Ext.should_receive(:udp_set_membership).with(pointer, multicast_address, interface_address, :uv_join_group)

      subject.join(multicast_address, interface_address)
    end
  end

  describe "#leave" do
    let(:multicast_address) { "239.255.0.1" }
    let(:interface_address) { "" }

    it "calls Libuv::Ext.udp_set_membership" do
      Libuv::Ext.should_receive(:udp_set_membership).with(pointer, multicast_address, interface_address, :uv_leave_group)

      subject.leave(multicast_address, interface_address)
    end
  end

  describe "#start_recv" do
    it "requires a block" do
      expect{ subject.start_recv }.to raise_error(ArgumentError)
    end

    it "calls Libuv::Ext.udp_recv_start" do
      Libuv::Ext.should_receive(:udp_recv_start).with(pointer, subject.method(:on_allocate), subject.method(:on_recv))

      subject.start_recv { |e, data, ip, port| }
    end
  end

  describe "#stop_recv" do
    it "calls Libuv::Ext.udp_recv_stop" do
      Libuv::Ext.should_receive(:udp_recv_stop).with(pointer)

      subject.stop_recv
    end
  end

  describe "#send" do
    let(:uv_udp_send_request) { double() }
    let(:buffer) { double() }
    let(:buffer_pointer) { double() }
    let(:ip_addr) { double() }
    let(:port) { 0 }
    let(:data) { "some data to send over UDP" }
    let(:size) { data.size }

    context "ipv4" do
      let(:ip) { "0.0.0.0" }

      before(:each) do
        Libuv::Ext.should_receive(:ip4_addr).with(ip, port).and_return(ip_addr)
      end

      it "calls Libuv::Ext.udp_send" do
        FFI::MemoryPointer.should_receive(:from_string).with(data).and_return(buffer_pointer)
        Libuv::Ext.should_receive(:buf_init).with(buffer_pointer, size).and_return(buffer)
        Libuv::Ext.should_receive(:create_request).with(:uv_udp_send).and_return(uv_udp_send_request)
        Libuv::Ext.should_receive(:udp_send).with(uv_udp_send_request, pointer, buffer, 1, ip_addr, an_instance_of(FFI::Function))
        loop.should_receive(:defer).once.and_return(promise)
        promise.should_receive(:promise).once

        subject.send(ip, port, data)
      end
    end

    context "ipv6" do
      let(:ip) { "::" }

      before(:each) do
        Libuv::Ext.should_receive(:ip6_addr).with(ip, port).and_return(ip_addr)
      end

      it "calls Libuv::Ext.udp_send6" do
        FFI::MemoryPointer.should_receive(:from_string).with(data).and_return(buffer_pointer)
        Libuv::Ext.should_receive(:buf_init).with(buffer_pointer, size).and_return(buffer)
        Libuv::Ext.should_receive(:create_request).with(:uv_udp_send).and_return(uv_udp_send_request)
        Libuv::Ext.should_receive(:udp_send6).with(uv_udp_send_request, pointer, buffer, 1, ip_addr, an_instance_of(FFI::Function))
        loop.should_receive(:defer).once.and_return(promise)
        promise.should_receive(:promise).once

        subject.send(ip, port, data)
      end
    end
  end

  describe "#enable_multicast_loop" do
    it "calls Libuv::Ext.udp_set_multicast_loop" do
      Libuv::Ext.should_receive(:udp_set_multicast_loop).with(pointer, 1)

      subject.enable_multicast_loop
    end
  end

  describe "#disable_multicast_loop" do
    it "calls Libuv::Ext.udp_set_multicast_loop" do
      Libuv::Ext.should_receive(:udp_set_multicast_loop).with(pointer, 0)

      subject.disable_multicast_loop
    end
  end

  describe "#multicast_ttl=" do
    let(:ttl) { 150 }

    it "calls Libuv::Ext.udp_set_multicast_ttl" do
      Libuv::Ext.should_receive(:udp_set_multicast_ttl).with(pointer, ttl)

      subject.multicast_ttl = ttl
    end
  end

  describe "#enable_broadcast" do
    it "calls Libuv::Ext.udp_set_broadcast" do
      Libuv::Ext.should_receive(:udp_set_broadcast).with(pointer, 1)

      subject.enable_broadcast
    end
  end

  describe "#disable_broadcast" do
    it "calls Libuv::Ext.udp_set_broadcast" do
      Libuv::Ext.should_receive(:udp_set_broadcast).with(pointer, 0)

      subject.disable_broadcast
    end
  end

  describe "#ttl=" do
    let(:ttl) { 220 }

    it "calls Libuv::Ext.udp_set_ttl" do
      Libuv::Ext.should_receive(:udp_set_ttl).with(pointer, ttl)

      subject.ttl = ttl
    end
  end
end