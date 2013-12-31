
shared_context 'with tcp server' do
  after(:each) do
    if @server_sock
      @server_sock.close rescue nil
    end
    if @server_thread
      @server_thread.kill
    end
  end

  let(:server_sock) do
    @server_sock = TCPServer.new(example_addr, example_ssl_port)
  end

  let(:server_thread) do
    @server_thread = Thread.new do
      begin
        #$stderr.puts("server_sock.accept_nonblock")
        peer = server_sock.accept_nonblock
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

  let(:client_sock) do
    #$stderr.puts "client_sock connecting"
    retries = 3
    begin
      #$stderr.puts "client_sock trying to connect (#{retries} left)"
      connected_socket = TCPSocket.new(example_addr, example_ssl_port)
    rescue Errno::ECONNREFUSED
      # Give the server thread another chance to get it up
      Thread.pass
      sleep 0.1
      retry if (retries -= 1) > 0
      raise $!
    end
    #$stderr.puts "client_sock connected #{connected_socket}"
    connected_socket
  end

  let(:io) do
    server_thread
    client_sock
    server_thread.value.write(data)
    client_sock
  end

end

