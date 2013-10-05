# TCP client with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Raptor::Socket::TCP::SSL < Raptor::Socket::TCP
  extend Forwardable

  # @!method context
  #   @return [OpenSSL::SSL::Context]
  def_delegator :@socket, :ssl_context, :context

  # @!method verify_mode
  #   @return [Fixnum] One of the `OpenSSL::SSL::VERIFY_*` constants
  def_delegator :@socket, :ssl_verify_mode, :verify_mode

  # @!method version
  #   @return [Symbol]  SSL version.
  def_delegator :@socket, :ssl_version, :version

  # @!method getpeername
  #   @return [String] Sockaddr data.
  def_delegator :@original_socket, :getpeername, :getpeername

  DEFAULT_CONFIG = {
    version:         :TLSv1,
    verify_mode:     OpenSSL::SSL::VERIFY_PEER,
    connect_timeout: 5
  }

  # @param  [Raptor::Socket]  socket
  # @param  [Hash]  options Options
  # @option config :connect_timeout [Integer] (5)
  #   {#connect Connection} timeout in seconds.
  # @option config :version [Symbol] (:TLSv1)
  # @option config :verify_mode [Integer] (OpenSSL::SSL::VERIFY_NONE)
  #   Peer verification mode.
  # @option config :context [OpenSSL::SSL::SSLContext] (nil)
  #   SSL context to use.
  def initialize( socket, options = {} )
    options = DEFAULT_CONFIG.merge( options )
    super

    if (@context = options[:context]).nil?
      @context = OpenSSL::SSL::SSLContext.new( options[:version] )
      @context.verify_mode = options[:verify_mode]
    end

    @original_socket = socket
    @socket = OpenSSL::SSL::SSLSocket.new( socket, @context )
  end

  # Starts the SSL/TLS handshake.
  #
  # @raise [Raptor::Socket::Error::ConnectionTimeout]
  #   On connection timeout (based on the `:connect_timeout` option).
  def connect
    begin
      Timeout.timeout( options[:connect_timeout] ) do
        @socket.connect
      end
    rescue Timeout::Error => e
      raise Raptor::Socket::Error::ConnectionTimeout, e.to_s
    end
  end

  # Ruby `Socket#gets` accepts:
  #
  # * `gets( sep = $/ )`
  # * `gets( limit = nil )`
  # * `gets( sep = $/, limit = nil )`
  #
  # `OpenSSL::SSL::SSLSocket#gets` however only supports `gets(sep=$/, limit=nil)`.
  # This hack allows SSLSocket to behave the same as Ruby Socket.
  #
  # @private
  def gets( *args )
    self.class.translate_errors do
      if args.size == 1
        if (arg = args.first).is_a? String
          @socket.gets arg
        else
          @socket.gets $/, arg
        end
      else
        @socket.gets *args
      end
    end
  end

  # @private
  def socket=( socket )
    @socket = socket
  end

end
