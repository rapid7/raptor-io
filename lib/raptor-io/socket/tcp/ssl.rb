
# TCP client with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class RaptorIO::Socket::TCP::SSL < RaptorIO::Socket::TCP

  # Create a new {SSL} from an already-connected
  # `OpenSSL::SSL::SSLSocket`.
  #
  # @example
  #   tcp_server = ::TCPServer.new()
  #   ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server)
  #   RaptorIO::Socket::TCP::SSL.from_openssl(ssl_server.accept)
  #
  # @see TCPServer::SSL
  # @param openssl_socket [OpenSSL::SSL::SSLSocket]
  # @return [SSL]
  def self.from_openssl(openssl_socket)
    raptor = self.allocate
    raptor.__send__(:socket=, openssl_socket)
    raptor.__send__(:plaintext_socket=, openssl_socket.to_io)
    raptor.options = {}
    raptor.options[:ssl_context] = openssl_socket.context

    raptor
  end

  # @!method ssl_context
  #   The SSL context for this encrypted stream.
  #
  #   @return [OpenSSL::SSL::Context]
  def_delegator :@socket, :ssl_context, :context

  # @!method verify_mode
  #   @return [Fixnum] One of the `OpenSSL::SSL::VERIFY_*` constants
  def_delegator :@socket, :ssl_verify_mode, :verify_mode

  # @!method version
  #   @return [Symbol]  SSL version.
  def_delegator :@socket, :ssl_version, :version

  # @param  socket  [RaptorIO::Socket]
  # @param  options [Hash]  Options
  # @option (see TCP#to_ssl)
  def initialize( socket, options = {} )
    options = DEFAULT_SSL_OPTIONS.merge( options )
    super

    @context = options[:context] || options[:ssl_context]

    if @context.nil?
      @context = OpenSSL::SSL::SSLContext.new( options[:ssl_version] )
      @context.verify_mode = options[:ssl_verify_mode]
    end

    @socket = OpenSSL::SSL::SSLSocket.new(socket.to_io, @context)
    begin
      #$stderr.puts("#{self.class}#initialize connecting")
      @socket.connect_nonblock
    rescue IO::WaitReadable, IO::WaitWritable => e
      #$stderr.puts("Wait*able #{e}, #{options[:connect_timeout].inspect}")
      if e.kind_of? IO::WaitReadable
        r,w,_ = IO.select([@socket], nil, nil, options[:connect_timeout])
      else
        r,w,_ = IO.select(nil, [@socket], nil, options[:connect_timeout])
      end

      if r.nil? && w.nil?
        #$stderr.puts("timeout")
        raise RaptorIO::Socket::Error::ConnectionTimeout.new(e.to_s)
      end

      retry
    end
  end

end
