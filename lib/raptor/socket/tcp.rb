# TCP client socket
class Raptor::Socket::TCP < Raptor::Socket

  # Default configuration options.
  DEFAULT_OPTIONS = {
    connect_timeout: 5,
  }

  # Default options for SSL streams connected through this socket.
  #
  # @see #to_ssl
  # @see TCP::SSL
  DEFAULT_SSL_OPTIONS = {
    ssl_version:         :TLSv1,
    ssl_verify_mode:     OpenSSL::SSL::VERIFY_NONE,
  }

  # @!attribute socket
  #   The underlying IO for this socket. Usually this is the
  #   `socket` passed to {#initialize}
  #   @return [IO]
  attr_accessor :socket

  # @param (see Socket#initialize)
  def initialize(socket, options = {})
    options = DEFAULT_OPTIONS.merge(options)
    super
    @plaintext_socket = @socket = socket
  end

  # @!method getpeername(string)
  #   Return a Sockaddr struct for the *socket*. Note that this is the
  #   @return [String] Sockaddr data.
  def_delegator :@plaintext_socket, :getpeername, :getpeername

  # @!method ungetc
  #   Pushes back one character onto the {#socket}'s read buffer. Note
  #   that some streams will *lose data* if this is called with a
  #   `string` larger than one byte or called more than once between
  #   calls to {#read}!
  #
  #   @param string [String] A single-byte string
  #   @return [nil]
  def_delegator :@socket, :ungetc, :ungetc

  def remote_address
    ::Addrinfo.new([ "AF_INET", options[:peer_port], options[:peer_host], options[:peer_host] ])
  end

  # Write `data` to the {#socket}.
  #
  # @param data [String,#to_s]
  # @return [Fixnum]
  def write(data)
    translate_errors do
      begin
        @socket.write_nonblock(data)
      rescue IO::WaitWritable
        IO.select(nil, [@socket])
        retry
      end
    end
  end

  # Read exactly `maxlen` bytes from the {#socket}. If fewer than
  # `maxlen` bytes are available for reading, wait until enough data
  # is sent.
  #
  # @note May block
  #
  # @param (see #read_nonblock)
  # @return (see #read_nonblock)
  def read(maxlen)
    buf = ""
    until 0 == maxlen
      prev_length = buf.length
      buf << readpartial(maxlen)
      maxlen -= buf.length - prev_length
    end
    buf
  end

  # Read at most `maxlen` bytes from the {#socket}.
  #
  # @note May block
  #
  # @param (see #read_nonblock)
  # @return (see #read_nonblock)
  def readpartial(maxlen = nil)
    begin
      read_nonblock(maxlen)
    rescue IO::WaitReadable
      IO.select([@socket])
      retry
    end
  end

  # Read at most `maxlen` bytes from the {#socket}.
  #
  # @param maxlen [Fixnum]
  # @return [String]
  def read_nonblock(maxlen = nil)
    translate_errors do
      @socket.read_nonblock(maxlen)
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
  # @note May block
  def gets(*args)
    translate_errors do
      if args.size == 1
        arg = args.first
        if arg.is_a?(Numeric)
          @socket.gets($/, arg)
        else
          @socket.gets(arg)
        end
      else
        @socket.gets(*args)
      end
    end
  end

  # Close this socket. If this socket is an SSL stream, closes both the
  # SSL stream and the underlying socket
  #
  # @return [void]
  def close
    begin
      super
    ensure
      if (!@plaintext_socket.closed?)
        @plaintext_socket.close
      end
    end
  end

  # Attempt to turn this into something usable by `IO.select`.
  #
  # @return [IO]
  def to_io
    IO.try_convert(@socket) || @socket
  end

  # Whether this socket is encrypted with SSL
  def ssl?
    !!(@socket.respond_to?(:context) && @socket.context)
  end

  # The version of SSL/TLS that was negotiated with the server.
  #
  # @return [String] See OpenSSL::SSL::SSLSocket#ssl_version for
  #   possible values
  # @return [nil] If this socket is not SSL
  def ssl_version
    return nil unless ssl?
    @socket.ssl_version
  end

  # @return [OpenSSL::SSL::SSLContext]
  # @return [nil] If this socket is not SSL (see {#ssl?})
  def ssl_context
    return nil unless ssl?
    @socket.context
  end

  # @note The original socket is replaced by the newly connected
  #   {TCP::SSL} socket
  #
  # Starts an SSL/TLS stream over this connection.
  #
  # Using this as opposed to directly instantiating {TCP::SSL} allows
  # you to start a TLS connection after data has already been exchanged
  # to enable things like `STARTTLS`.
  #
  # @note May block
  #
  # @param ssl_options [Hash]  Options
  # @option ssl_options :ssl_version [Symbol] (:TLSv1)
  # @option ssl_options :ssl_verify_mode [Constant] (OpenSSL::SSL::VERIFY_PEER)
  #   Peer verification mode.
  # @option ssl_config :ssl_context [OpenSSL::SSL::SSLContext] (nil)
  #   SSL context to use.
  #
  # @return [Raptor::Socket::TCP::SSL] A new Socket with an established
  #   SSL connection
  def to_ssl(ssl_options = {})
    if ssl_options[:ssl_context]
      options[:ssl_context] = ssl_options[:ssl_context]
    else
      ssl_options = DEFAULT_SSL_OPTIONS.merge(ssl_options)
      options[:ssl_context] = OpenSSL::SSL::SSLContext.new.tap do |ctx|
        ctx.ssl_version = ssl_options[:ssl_version]
        ctx.verify_mode = ssl_options[:ssl_verify_mode]
      end
    end

    s = Raptor::Socket::TCP::SSL.new(@plaintext_socket, options)
    @socket = s
    s
  end

  private
  attr_accessor :plaintext_socket

  def translate_errors(&block)
    yield
  rescue Errno::ECONNRESET, Errno::EPIPE
    raise Raptor::Socket::Error::BrokenPipe
  rescue Errno::ECONNREFUSED
    raise Raptor::Socket::Error::ConnectionRefused
  end

end
