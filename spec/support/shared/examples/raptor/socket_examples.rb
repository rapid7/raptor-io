shared_examples "a socket" do
  it "has important methods of IO" do
    expect(subject).to respond_to(:to_io)
    expect(subject).to respond_to(:read)
    expect(subject).to respond_to(:readpartial)
    expect(subject).to respond_to(:write)
    expect(subject).to respond_to(:close)
    expect(subject).to respond_to(:closed?)
  end

  describe "#gets" do
    it "should convert Errno::ECONNRESET to BrokenPipe" do
      io.stub(:gets).and_raise(Errno::ECONNRESET)
      expect {
        subject.gets
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end

    it "should convert Errno::EPIPE to BrokenPipe" do
      io.stub(:gets).and_raise(Errno::EPIPE)
      expect {
        subject.gets
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end
  end

  describe "#read" do
    it "should convert Errno::ECONNRESET to BrokenPipe" do
      io.stub(:read).and_raise(Errno::ECONNRESET)
      expect {
        subject.read(1)
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end

    it "should convert Errno::EPIPE to BrokenPipe" do
      io.stub(:read).and_raise(Errno::EPIPE)
      expect {
        subject.read(1)
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end
  end

  describe "#write" do
    it "should convert Errno::ECONNRESET to BrokenPipe" do
      io.stub(:write).and_raise(Errno::ECONNRESET)
      expect {
        subject.write("asdf")
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end

    it "should convert Errno::EPIPE to BrokenPipe" do
      io.stub(:write).and_raise(Errno::EPIPE)
      expect {
        subject.write("asdf")
      }.to raise_error(Raptor::Socket::Error::BrokenPipe)
    end
  end

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
