# largely stolen from celluloid-io
shared_context 'with ssl server' do
  let(:server_cert) { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.crt')) }
  let(:server_key)  { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.key')) }
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
      Thread.pass while thread.status && thread.status != 'sleep'
      thread.join unless thread.status
    end
  end

  let(:unconnected_client_sock) do
    s = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM, 0)
  end

  let(:client_sock) do
    retries = 3
    begin
       s = TCPSocket.new(example_addr, example_ssl_port)
    rescue Errno::ECONNREFUSED
      retry if (retries -= 1) > 0
    end
    s
  end

  def with_ssl_sockets
    server_thread
    # Allow the server thread a chance to set up if it got scheduled
    # out before doing so.
    Thread.pass
    ssl_client.connect

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
