require 'spec_helper'
require 'raptor/socket'

describe Raptor::Socket::TCPServer::SSL do
  subject { described_class.new(io) }
end
