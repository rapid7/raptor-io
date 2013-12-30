
# TCP client with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Raptor::Socket::TCP::SSL < Raptor::Socket::TCP

  # Create a new {SSL} from an already-connected
  # {OpenSSL::SSL::SSLSocket}.
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

  # @!method context
  #   @return [OpenSSL::SSL::Context]
  def_delegator :@socket, :ssl_context, :context

  # @!method verify_mode
  #   @return [Fixnum] One of the `OpenSSL::SSL::VERIFY_*` constants
  def_delegator :@socket, :ssl_verify_mode, :verify_mode

  # @!method version
  #   @return [Symbol]  SSL version.
  def_delegator :@socket, :ssl_version, :version

  # @param  [Raptor::Socket]  socket
  # @param  [Hash]  options Options
  # @option (see TCP#to_ss)
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
      @socket.connect_nonblock
    rescue IO::WaitReadable => e
      r,w,_ = IO.select([@socket],[@socket],nil,options[:connect_timeout])
      if r.nil? && w.nil?
        raise Raptor::Socket::Error::ConnectionTimeout.new(e.to_s)
      end
      retry
    end
  end

  # @return [self]
  def to_ssl(*args)
    self
  end

end
