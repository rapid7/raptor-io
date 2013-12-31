require 'spec_helper'
require 'raptor-io/socket'

describe RaptorIO::Socket::TCP do

  subject { described_class.new(io, opts) }

  let(:io) { StringIO.new }
  let(:opts) { {} }

  it_behaves_like 'a client socket'

  it { should respond_to(:to_ssl) }
end
