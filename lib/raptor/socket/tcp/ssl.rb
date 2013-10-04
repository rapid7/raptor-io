# TCP client with SSL encryption.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Raptor::Socket::TCP::SSL < Raptor::Socket::TCP
  extend Forwardable

  def_delegators :@sock, :close, :closed?, :to_io

  # @!method ssl_context
  #   @return [OpenSSL::SSL::Context]
  def_delegator :@sock, :ssl_context, :context

  # @!method ssl_verify_mode
  #   @return [Fixnum] One of the OpenSSL::SSL::VERIFY_* constants
  def_delegator :@sock, :ssl_verify_mode, :verify_mode

  # @!method ssl_version
  #   @return [Symbol]
  def_delegator :@sock, :ssl_version, :version

  # @!method getpeername
  #   @return [String] Sockaddr data.
  def_delegator :@original_socket, :getpeername, :getpeername

  DEFAULT_CONFIG = {
    version:     :TLSv1,
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }

  # @param  [Raptor::Socket]  sock
  # @param  [Hash]  config Options
  # @option config :version [Symbol] (:TLSv1)
  # @option config :verify_mode [Constant] (OpenSSL::SSL::VERIFY_NONE)
  #   Peer verification mode.
  # @option config :context [OpenSSL::SSL::SSLContext] (nil)
  #   SSL context to use.
  def initialize( sock, config = {} )
    config = DEFAULT_CONFIG.merge( config )
    super

    if (@context = config[:context]).nil?
      @context = OpenSSL::SSL::SSLContext.new( config[:version] )
      @context.verify_mode = config[:verify_mode]
    end

    @original_socket = sock
    @sock = OpenSSL::SSL::SSLSocket.new( sock, @context )
  end


  # Ruby Socket#gets accepts:
  #
  # * gets(sep=$/)
  # * gets(limit=nil)
  # * gets(sep=$/, limit=nil)
  #
  # OpenSSL::SSL::SSLSocket#gets however only supports `gets(sep=$/, limit=nil)`.
  # This hack allows SSLSocket to behave the same as Ruby Socket.
  #
  # @private
  def gets( *args )
    self.class.translate_errors do
      if args.size == 1
        if (arg = args.first).is_a? String
          @sock.gets arg
        else
          @sock.gets $/, arg
        end
      else
        @sock.gets *args
      end
    end
  end

  # @private
  def sock=( sock )
    @sock = sock
  end

end
