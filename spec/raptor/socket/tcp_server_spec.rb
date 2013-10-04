
require 'spec_helper'

require 'raptor/socket'

describe Raptor::Socket::TCPServer do
  subject { described_class.new(io) }
  let(:io) {
    sio = StringIO.new
    # Bind, listen, and connect all return 0 unless an exception is
    # raised
    sio.stub(:bind).and_return(0)
    sio.stub(:listen).and_return(0)
    sio.stub(:accept).and_return { StringIO.new }

    sio
  }

  it_behaves_like "a server socket"
end

