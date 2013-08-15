require 'spec_helper'

describe Libuv::FSEvent do
  let(:handle_name) { :fs_event }
  let(:loop) { double() }
  let(:pointer) { double() }
  subject { Libuv::FSEvent.new(loop, pointer) { |e, filename, type| } }

  it_behaves_like 'a handle'
end
