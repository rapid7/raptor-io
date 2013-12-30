
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
    @ssl_server_sock = OpenSSL::SSL::SSLServer.new(server_sock, server_context)
  end

  let(:io) do
    $stderr.puts("with_ssl_server :io")
    server_thread
    $stderr.puts("io connecting")
    client_sock
    $stderr.puts("ssl thread")
    @ssl_server_thread = Thread.new { ssl_server_sock.accept }
    Thread.pass
    client_sock
  end

  subject do
    $stderr.puts("with_ssl_server subject")
    s = described_class.new(io, opts)
    $stderr.puts("Subject:  #{s.inspect}")
    peer = @ssl_server_thread.value
    $stderr.puts("ssl_server_thread.value #{peer}")
    s
  end

  after(:each) do
    @ssl_server_sock.close if @ssl_server_sock
    @ssl_server_thread.kill if @ssl_server_thread
  end

end

