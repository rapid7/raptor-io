shared_examples_for "a client socket" do
  let(:data) { "0\n1\n2\n3\n4\n".force_encoding( 'binary' ) }

  context do
    subject { described_class.new(io, opts) }
    it "has important methods of IO" do
      expect(subject).to respond_to(:to_io)
      expect(subject).to respond_to(:read)
      expect(subject).to respond_to(:readpartial)
      expect(subject).to respond_to(:write)
      expect(subject).to respond_to(:close)
      expect(subject).to respond_to(:closed?)
    end
  end

  describe "#gets" do

    it "converts Errno::ECONNRESET to BrokenPipe" do

      io.stub(:gets).and_raise(Errno::ECONNRESET)
      expect {
        subject.gets
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end

    it "converts Errno::EPIPE to BrokenPipe" do
      io.stub(:gets).and_raise(Errno::EPIPE)
      expect {
        subject.gets
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end

    context "with a TCPSocket for IO" do
      let(:data) { "0\n1\n2\n3\n4\n".force_encoding( 'binary' ) }
      let(:data_io) { StringIO.new( data ) }

      include_context "with tcp server"

      it 'returns each line from the buffer' do
        5.times do |i|
          line = subject.gets
          line.should == data_io.gets
        end
      end

      context 'when called with Fixnum arg'  do
        it 'reads and returns at most that number of bytes' do
          5.times do |i|
            line = subject.gets( 1 )
            line.size.should == 1
            line.should == data_io.gets( 1 )
          end
        end
        it 'reads and returns at most that number of bytes' do
          5.times do |i|
            subject.gets( 100 ).should == data_io.gets( 100 )
          end
        end
      end

      context 'when called with String arg' do
        let(:data) { '0--1--2--3--4--'.force_encoding( 'binary' ) }

        it 'uses it as a newline separator' do
          5.times do |i|
            subject.gets( '--' ).should == data_io.gets( '--' )
          end
        end
      end

      context 'when called String and Fixnum args' do
        let(:data) { '1--22--333--4444--55555--'.force_encoding( 'binary' ) }

        it 'uses the String as a newline separator and the Fixnum as a max-size' do
          5.times do |i|
            line = subject.gets('--', 2)
            line.size.should be_between(0, 2)
            line.should == data_io.gets('--', 2)
          end
        end
      end
    end

  end

  describe "#read" do
    let(:io) { StringIO.new }
    it "converts Errno::ECONNRESET to BrokenPipe" do
      io.stub(:read).and_raise(Errno::ECONNRESET)
      expect {
        subject.read(1)
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end

    it "converts Errno::EPIPE to BrokenPipe" do
      io.stub(:read).and_raise(Errno::EPIPE)
      expect {
        subject.read(1)
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end

    context 'with server' do
      include_context "with tcp server"
      let(:data) { "0\n1\n2\n3\n4\n".force_encoding( 'binary' ) }
      it 'returns what the server wrote' do
        subject.read(data.length).should eql(data)
      end
    end
  end

  describe "#write" do
    let(:io) { StringIO.new }

    it "converts Errno::ECONNRESET to BrokenPipe" do
      io.stub(:write).and_raise(Errno::ECONNRESET)
      expect {
        subject.write("asdf")
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end

    it "converts Errno::EPIPE to BrokenPipe" do
      io.stub(:write).and_raise(Errno::EPIPE)
      expect {
        subject.write("asdf")
      }.to raise_error(RaptorIO::Socket::Error::BrokenPipe)
    end
  end

end

shared_examples "a server socket" do
  it { should respond_to(:bind) }
  it { should respond_to(:listen) }
  it { should respond_to(:accept) }
end
