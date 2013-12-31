require 'spec_helper'
require 'raptor/socket'

describe Raptor::Socket::TCPServer::SSL do
  include_context 'with tcp server'

  let(:server_cert) { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.crt')) }
  let(:server_key)  { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.key')) }
  let(:server_context) do
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = OpenSSL::X509::Certificate.new(server_cert)
      context.key  = OpenSSL::PKey::RSA.new(server_key)
    end
  end

  subject(:ssl_server) do
    described_class.new(server_sock, context: server_context )
  end

  let(:data) { 'test'.force_encoding( 'binary' ) }

  describe '#accept_nonblock' do
    it 'returns a connected peer as a Raptor::Socket::TCP::SSL socket' do
      ssl_server
      ssl_client = OpenSSL::SSL::SSLSocket.new(client_sock)

      Thread.new do
        Thread.pass
        #$stderr.puts "ssl_client connecting"
        ssl_client.connect
        #$stderr.puts "ssl_client CONNECTED"
      end

      ssl_peer = nil

      begin
        #$stderr.puts "ssl_server accepting"
        ssl_peer = ssl_server.accept_nonblock
        #$stderr.puts "ssl_server ACCEPTED"
      rescue IO::WaitReadable
        #$stderr.puts "ssl_server waiting for a client"
        Raptor::Socket.select([ssl_server])
        retry
      end

      #$stderr.puts("ssl_server accepted peer #{ssl_peer}")
      ssl_peer.should be_kind_of Raptor::Socket::TCP::SSL

      select( [], [ssl_peer] )
      ssl_peer.write data

      select( [ssl_client] )
      ssl_client.read(data.size).should == data

    end
  end
end
