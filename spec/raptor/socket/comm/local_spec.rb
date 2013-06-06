require 'spec_helper'

require 'raptor/socket'

describe Raptor::Socket::Comm::Local do
  describe "#support_ipv6?" do
    # These are ghetto tests. It assumes the implementation for
    # determining support.
    it "should be true if we can create ipv6 sockets" do
      socket_inst  = double("sock")
      socket_inst.stub(:close)

      ::Socket.should_receive(:new).with(::Socket::AF_INET6, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP).and_return(socket_inst)
      subject.support_ipv6?.should be_true
    end
    it "should be false if ::Socket::AF_INET6 is not defined" do
      ::Socket.should_receive(:const_defined?).and_return(false)
      subject.support_ipv6?.should be_false
    end
    it "should be false if we cannot create ipv6 sockets" do
      ::Socket.should_receive(:new).and_raise(RuntimeError)
      subject.support_ipv6?.should be_false
    end
  end
end
