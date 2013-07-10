
require 'spec_helper'

require 'raptor/socket'

describe Raptor::Socket::Tcp do
  subject do
    described_class.new(io)
  end
  let(:io) { io = StringIO.new }

  it_behaves_like "a client socket"
end
