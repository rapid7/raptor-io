require 'spec_helper'
require 'raptor/socket'

describe Raptor::Socket::TCPServer::SSL do
  include_context 'with ssl server'

  let(:io) { server }
  let(:ssl_server) { described_class.new(io, context: server_context ) }
  let(:ssl_client) { Raptor::Socket::TCP::SSL.new( client_sock, verify_mode: OpenSSL::SSL::VERIFY_NONE ) }
  let(:data) { 'test'.force_encoding( 'binary' ) }

  subject { ssl_server }

  describe '#accept' do
    it 'returns a client connection as a Raptor::Socket::TCP::SSL socket' do
      server_thread

      Thread.pass

      ssl_client.connect

      ssl_peer = nil
      begin
        ssl_peer = server_thread.value
        ssl_peer.should be_kind_of Raptor::Socket::TCP::SSL

        ssl_peer.write data
        ssl_client.read(data.size).should == data
      ensure
        server_thread.join
        ssl_server.close
        ssl_peer.close if ssl_peer
      end
    end
  end

  describe '#accept_nonblock' do
    it 'returns a client connection as a Raptor::Socket::TCP::SSL socket without blocking' do
      ssl_server

      Thread.new do
        ssl_client.connect
      end
      Thread.pass

      ssl_peer = nil
      begin
        begin
          ssl_peer = ssl_server.accept_nonblock
        rescue IO::WaitReadable
          IO.select([ssl_server])
          retry
        end

        ssl_peer.should be_kind_of Raptor::Socket::TCP::SSL

        select( [], [ssl_peer] )
        ssl_peer.write data

        select( [ssl_client] )
        ssl_client.read(data.size).should == data
      ensure
        ssl_server.close
        ssl_peer.close if ssl_peer
      end
    end
  end
end
