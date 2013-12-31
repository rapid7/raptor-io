# TCP server with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class RaptorIO::Socket::TCPServer::SSL < RaptorIO::Socket::TCPServer

  def initialize( socket, options = {} )
    #p options[:context].frozen?
    super
    #p options[:context].frozen?

    @context = options[:context]
    if @context.nil?
      @context = OpenSSL::SSL::SSLContext.new( options[:ssl_version] )
      @context.verify_mode = options[:verify_mode]
    end

    @plaintext_socket = socket
    @socket = OpenSSL::SSL::SSLServer.new( socket, @context )
  end

  # Accepts a client connection.
  #
  # @see Socket::TCP::SSL.from_openssl
  # @return [RaptorIO::Socket::TCP::SSL]
  def accept
    RaptorIO::Socket::TCP::SSL.from_openssl(@socket.accept)
  end

  # Accepts a client connection without blocking.
  #
  # @see Socket::TCP::SSL.from_openssl
  # @return [RaptorIO::Socket::TCP::SSL]
  # @raise [IO::WaitWritable]
  def accept_nonblock
    RaptorIO::Socket::TCP::SSL.from_openssl(@socket.accept_nonblock)
  end

  # Close this SSL stream and the underlying socket
  #
  # @return [void]
  def close
    begin
      @socket.close
    ensure
      if (!@plaintext_socket.closed?)
        @plaintext_socket.close
      end
    end
  end


end
