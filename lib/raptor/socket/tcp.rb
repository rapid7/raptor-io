
# A TCP client socket
class Raptor::Socket::Tcp < Raptor::Socket

  # Number of seconds to wait for a connection to complete
  DEFAULT_CONNECT_TIMEOUT = 5

  def initialize(sock, config={})
    super
    config[:connect_timeout] ||= DEFAULT_CONNECT_TIMEOUT
  end

  # Turn this socket into an SSL stream
  #
  # @param ssl_opts [Hash] Options for
  # @return 0
  def ssl_client_connect(ssl_opts={})
    if ssl_opts[:ssl_context]
      @ssl_context = ssl_opts[:ssl_context]
    else
      ssl_init_context
    end
    ssl = OpenSSL::SSL::SSLSocket.new(@sock, @ssl_context)

    Timeout.timeout(config[:connect_timeout]) do
      ssl.connect
    end

    # Now that we've set up an encrypted session, we shouldn't ever
    # really call methods on the underlying socket. Replace it with the
    # new SSLSocket.
    @sock = ssl

    0
  end

  protected

  # Use values from {#config} to create an SSL context.
  #
  # @return [OpenSSL::SSL:SSLContext]
  def ssl_init_context
    config[:ssl_version]     ||= :TLSv1
    config[:ssl_verify_mode] ||= OpenSSL::SSL::VERIFY_PEER

    @ssl_context = OpenSSL::SSL::SSLContext.new(config[:ssl_version])
    @ssl_context.verify_mode = config[:ssl_verify_mode]

    @ssl_context
  end

end

