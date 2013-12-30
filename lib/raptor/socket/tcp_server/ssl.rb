# TCP server with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Raptor::Socket::TCPServer::SSL < Raptor::Socket::TCPServer

  def initialize( socket, options = {} )
    super

    if (@context = options[:context]).nil?
      @context = OpenSSL::SSL::SSLContext.new( options[:version] )
      @context.verify_mode = options[:verify_mode]
    end

    @original_socket = socket
    @socket = OpenSSL::SSL::SSLServer.new( socket, @context )
  end

  # Accepts a client connection.
  #
  # @see Socket::TCP::SSL.from_openssl
  # @return [Raptor::Socket::TCP::SSL]
  def accept
    Raptor::Socket::TCP::SSL.from_openssl(@socket.accept)
  end

  # Accepts a client connection without blocking.
  #
  # @see Socket::TCP::SSL.from_openssl
  # @return [Raptor::Socket::TCP::SSL]
  # @raise [IO::WaitWritable]
  def accept_nonblock
    Raptor::Socket::TCP::SSL.from_openssl(@socket.accept_nonblock)
  end

end
