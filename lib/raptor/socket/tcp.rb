# A TCP client socket
class Raptor::Socket::TCP < Raptor::Socket

  # Number of seconds to wait for a connection to complete
  DEFAULT_CONNECT_TIMEOUT = 5

  def initialize( sock, config = {} )
    super
    config[:connect_timeout] ||= DEFAULT_CONNECT_TIMEOUT
  end

  # @param  [Hash]  ssl_config Options
  # @option options [Symbol]  version (:TLSv1)
  # @option options [Constant]  verify_mode (OpenSSL::SSL::VERIFY_NONE)
  #   Peer verification mode.
  # @option options [OpenSSL::SSL::SSLContext]  context (nil)
  #   SSL context to use.
  def to_ssl!( ssl_config = { } )
    @sock = Raptor::Socket::SSLTCP.new( @sock, config.merge( ssl_config ) )
    @sock.connect
    nil
  end

end
