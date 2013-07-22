
# Requires let(:tcp_port) and let(:udp_port) to be set to something
shared_examples "a comm" do
  it { should respond_to(:create_tcp) }
  it { should respond_to(:create_tcp_server) }
  #pending { should respond_to(:create_udp) }
  #pending { should respond_to(:create_udp_server) }

  let(:peer_host) { "127.0.0.1" }

  describe "#create_tcp" do
    it "should create a TCP socket" do
      sock = comm.create_tcp(peer_host: peer_host, peer_port: tcp_port)
      sock.should be_a(Raptor::Socket::Tcp)
      raddr = sock.remote_address
      raddr.should be_a(::Addrinfo)
      raddr.ip_address.should == peer_host
      raddr.ip_port.should == tcp_port
    end
  end

end


