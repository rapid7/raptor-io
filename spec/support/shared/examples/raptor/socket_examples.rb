shared_examples "a socket" do
  it { should respond_to(:to_io) }
  it { should respond_to(:syswrite) }
  it { should respond_to(:sysread) }
  it { should respond_to(:read) }
  it { should respond_to(:write) }
  # Don't exist on JRuby, may need to revisit
  #it { should respond_to(:read_nonblock) }
  #it { should respond_to(:write_nonblock) }
  it { should respond_to(:close) }
end

shared_examples "a client socket" do
  it_behaves_like "a socket"
  # Not true for TCPSockets, which connect automatically
  #it { should respond_to(:connect) }
  #it { should respond_to(:connect_nonblock) }
end

shared_examples "a server socket" do
  it_behaves_like "a socket"
  it { should respond_to(:bind) }
  it { should respond_to(:listen) }
  it { should respond_to(:accept) }
end
