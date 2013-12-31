
shared_context 'with ssl server' do
  include_context 'with tcp server'

  let(:server_cert) { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.crt')) }
  let(:server_key)  { File.read(File.join(fixtures_path, 'raptor', 'socket', 'ssl_server.key')) }
  let(:server_context) do
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = OpenSSL::X509::Certificate.new(server_cert)
      context.key  = OpenSSL::PKey::RSA.new(server_key)
    end
  end

  let(:ssl_server_sock) do
    @ssl_server_sock = OpenSSL::SSL::SSLSocket.new(server_sock, server_context)
  end

  let(:io) do
    #$stderr.puts("with_ssl_server :io, starting tcp server thread")
    server_thread

    #$stderr.puts(":io client_sock connecting")
    client_sock

    #$stderr.puts("starting ssl accept thread")
    @ssl_server_thread = Thread.new { ssl_server_sock.accept }
    #$stderr.puts(" ssl accept thread, #{@ssl_server_thread.inspect}")

    # pass to make sure the server thread gets a slice before we return
    Thread.pass

    # this should now be a connected ::TCPSocket
    client_sock
  end

  let(:server_thread) do
    @server_thread = Thread.new do
      begin
        #$stderr.puts("ssl_server_sock.accept_nonblock")
        peer = ssl_server_sock.accept_nonblock
      rescue IO::WaitReadable, IO::WaitWritable
        #$stderr.puts(":server_sock waiting for a client")
        select([server_sock], [server_sock])
        #$stderr.puts(":server_sock retrying")
        retry
      end
      #$stderr.puts(":server_sock accepted peer #{peer.inspect}")
      peer
    end
    @server_thread

  end

  subject do
    #$stderr.puts("with_ssl_server subject (#{described_class})")
    s = described_class.new(io, opts)

    #$stderr.puts("Subject:  #{s.inspect}")
    peer = @ssl_server_thread.value
    #$stderr.puts("ssl_server_thread.value #{peer}")
    s
  end

  after(:each) do
    @ssl_server_sock.close if @ssl_server_sock
    @ssl_server_thread.kill if @ssl_server_thread
  end

end

