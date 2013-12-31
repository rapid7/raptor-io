require 'spec_helper'
require 'raptor-io/socket'

describe RaptorIO::Socket::TCPServer do
  subject { described_class.new(io, opts) }
  let(:opts) { {} }
  let(:io) {
    sio = StringIO.new
    # Bind, listen, and connect all return 0 unless an exception is
    # raised
    sio.stub(:bind).and_return(0)
    sio.stub(:listen).and_return(0)
    sio.stub(:accept).and_return { StringIO.new }

    sio
  }

  it_behaves_like 'a server socket'
end
