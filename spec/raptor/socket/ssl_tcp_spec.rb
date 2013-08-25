
require 'spec_helper'

require 'raptor/socket'
require 'raptor/socket/ssl_tcp'

describe Raptor::Socket::SslTcp do
  subject(:ssl_client) do
    described_class.new(io, opts)
  end
  let(:opts) do
    {
      :ssl_version => :TLSv1,
      :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
    }
  end
  let(:io) { io = StringIO.new }

  it { should respond_to :ssl_client_connect }
  it { should respond_to :ssl_context }
  it { should respond_to :ssl_version }
  it { should respond_to :ssl_verify_mode }

  it_behaves_like "a client socket"

  # largely stolen from celluloid-io
  context "with a server" do
    let(:server_cert) { File.read(File.join(fixtures_path, "raptor", "socket", "raptor_spec.crt")) }
    let(:server_key)  { File.read(File.join(fixtures_path, "raptor", "socket", "raptor_spec.key")) }
    let(:server_context) do
      OpenSSL::SSL::SSLContext.new.tap do |context|
        context.cert = OpenSSL::X509::Certificate.new(server_cert)
        context.key  = OpenSSL::PKey::RSA.new(server_key)
      end
    end
    let(:server)     { TCPServer.new(example_addr, example_ssl_port) }
    let(:ssl_server) { OpenSSL::SSL::SSLServer.new(server, server_context) }
    let(:server_thread) do
      Thread.new { ssl_server.accept }.tap do |thread|
        Thread.pass while thread.status && thread.status != "sleep"
        thread.join unless thread.status
      end
    end

    let(:io) do
      s = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM, 0)
      s
    end

    let(:data) { "wheeee!!".force_encoding("binary") }

    describe "#read_nonblock" do
      it "should return what the server wrote" do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write(data)
          select([ssl_client], nil, nil, 0.1)
          ssl_client.read_nonblock(data.length).should eql(data)
        end
      end
    end

    describe "#readpartial" do
      it "should return what the server wrote" do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write(data)
          select([ssl_client], nil, nil, 0.1)
          ssl_client.readpartial(data.length).should eql(data)
        end
      end
    end

    describe "#read" do
      it "should return what the server wrote" do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write(data)
          select([ssl_client], nil, nil, 0.1)
          ssl_client.read(data.length).should eql(data)
        end
      end
    end

    def with_ssl_sockets
      server_thread
      # Allow the server thread a chance to set up if it got scheduled
      # out before doing so.
      Thread.pass
      io.connect(::Socket.pack_sockaddr_in(example_ssl_port, example_addr))
      ssl_client.ssl_client_connect

      begin
        ssl_peer = server_thread.value
        yield ssl_client, ssl_peer
      ensure
        server_thread.join
        ssl_server.close
        ssl_client.close
        ssl_peer.close
      end
    end

  end
end

