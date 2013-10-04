# TCP server with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Raptor::Socket::TCPServer::SSL < Raptor::Socket::TCPServer

  def initialize( sock, config = {} )
    super

    if (@context = config[:context]).nil?
      @context = OpenSSL::SSL::SSLContext.new( config[:version] )
      @context.verify_mode = config[:verify_mode]
    end

    @original_socket = sock
    @sock = OpenSSL::SSL::SSLServer.new( sock, @context )
  end

  def accept
    openssl_to_raptor @sock.accept
  end

  def accept_nonblock
    openssl_to_raptor @sock.accept_nonblock
  end

  private

  def openssl_to_raptor( openssl_socket )
    s = Raptor::Socket::TCP::SSL.new( openssl_socket.to_io, config )
    s.sock = openssl_socket
    s
  end

end
