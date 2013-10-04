# TCP client socket
class Raptor::Socket::TCP < Raptor::Socket

  # Number of seconds to wait for a connection to complete
  DEFAULT_CONNECT_TIMEOUT = 5

  def initialize( sock, config = {} )
    super
    config[:connect_timeout] ||= DEFAULT_CONNECT_TIMEOUT
  end

  # @param  [Hash]  ssl_config Options
  # @option ssl_config :version [Symbol] (:TLSv1)
  # @option ssl_config :verify_mode [Constant] (OpenSSL::SSL::VERIFY_NONE)
  #   Peer verification mode.
  # @option ssl_config :context [OpenSSL::SSL::SSLContext] (nil)
  #   SSL context to use.
  def to_ssl!( ssl_config = { } )
    @sock = Raptor::Socket::TCP::SSL.new( @sock, config.merge( ssl_config ) )
    @sock.connect
    nil
  end

end
