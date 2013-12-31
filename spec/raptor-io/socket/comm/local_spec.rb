require 'spec_helper'

require 'raptor-io/socket'

describe RaptorIO::Socket::Comm::Local do
  subject(:comm_local) { described_class.new }

  context "with a server to connect to" do
    let(:tcp_port) { 9999 }
    let(:udp_port) { 9090 }
    before do
      @tcp_server = ::TCPServer.new(tcp_port)
    end
    after do
      @tcp_server.close
    end

    subject(:comm) { described_class.new }
    it_behaves_like "a comm"
  end

  describe '#resolve' do
    it 'should resolve a hostname to an IP address' do
      ['127.0.0.1', 'fe80::1%lo0'].should include(comm_local.resolve('localhost'))
    end
  end

  describe '#reverse_resolve' do
    it 'should resolve a hostname to an IP address' do
      comm_local.reverse_resolve( '127.0.0.1' ).should == 'localhost'
    end
  end

  describe "#support_ipv6?" do
    # These are ghetto tests. It assumes the implementation for
    # determining support.
    it "should be true if we can create ipv6 sockets" do
      socket_inst = double("sock")
      socket_inst.stub(:close)

      ::Socket.should_receive(:new).with(::Socket::AF_INET6, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP).and_return(socket_inst)
      comm_local.support_ipv6?.should be_true
    end
    it "should be false if ::Socket::AF_INET6 is not defined" do
      ::Socket.should_receive(:const_defined?).and_return(false)
      comm_local.support_ipv6?.should be_false
    end
    it "should be false if we cannot create ipv6 sockets" do
      ::Socket.should_receive(:new).and_raise(RuntimeError)
      comm_local.support_ipv6?.should be_false
    end
  end

end
