# TCP client socket
class Raptor::Socket::TCP < Raptor::Socket

  # @note Do not use the established connection again as it will remain
  #   unencrypted. Instead, use the returned **encrypted** socket to communicate
  #   with the remote end.
  #
  # Starts an SSL/TLS stream over this established connection.
  #
  # @param  [Hash]  ssl_options Options
  # @option ssl_config :version [Symbol] (:TLSv1)
  # @option ssl_config :verify_mode [Constant] (OpenSSL::SSL::VERIFY_NONE)
  #   Peer verification mode.
  # @option ssl_config :context [OpenSSL::SSL::SSLContext] (nil)
  #   SSL context to use.
  #
  # @return Raptor::Socket::TCP::SSL
  def to_ssl( ssl_options = { } )
    s = Raptor::Socket::TCP::SSL.new( @socket, options.merge( ssl_options ) )
    s.connect
    s
  end

end
