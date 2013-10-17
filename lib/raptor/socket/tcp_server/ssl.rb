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
  # @return [Raptor::Socket::TCP::SSL]
  def accept
    openssl_to_raptor @socket.accept
  end

  # Accepts a client connection without blocking.
  #
  # @return [Raptor::Socket::TCP::SSL]
  def accept_nonblock
    openssl_to_raptor @socket.accept_nonblock
  end

  private

  def openssl_to_raptor( openssl_socket )
    s = Raptor::Socket::TCP::SSL.new( openssl_socket.to_io, options )
    s.socket = openssl_socket
    s
  end

end
