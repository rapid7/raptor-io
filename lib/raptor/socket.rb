require 'forwardable'
require 'raptor/ruby'

# A basic class for specific transports to inherit from. Analogous to
# stdlib's BasicSocket
class Raptor::Socket
  extend Forwardable

  require 'raptor/socket/error'
  require 'raptor/socket/switch_board'
  require 'raptor/socket/tcp'
  require 'raptor/socket/tcp/ssl'
  require 'raptor/socket/tcp_server'
  require 'raptor/socket/tcp_server/ssl'

  class << self

    # Captures Ruby exceptions and converts them to Raptor Errors.
    #
    # @param  [Block] block Block to run.
    def translate_errors( &block )
      block.call
    rescue ::Errno::EPIPE, ::Errno::ECONNRESET => e
      raise Raptor::Socket::Error::BrokenPipe, e.to_s
    rescue ::Errno::ECONNREFUSED => e
      raise Raptor::Socket::Error::ConnectionRefused, e.to_s
    end

    # Delegates to `::Socket.getaddrinfo`.
    def getaddrinfo( *args )
      begin
        ::Socket.getaddrinfo( *args )
      # OSX raises SocketError.
      rescue ::SocketError, ::Errno::ENOENT => e
        raise Raptor::Socket::Error::CouldNotResolve.new( e.to_s )
      end
    end

    # Delegate to Ruby Socket.
    def method_missing(meth, *args, &block)
      if ::Socket.respond_to?(meth)
        translate_errors do
          # not send() because that sends a packet.  =)
          ::Socket.__send__(meth, *args, &block)
        end
      else
        super
      end
    end

    def respond_to_missing?(meth, include_private=false)
      ::Socket.respond_to?(meth, include_private)
    end
  end

  # Options for this socket.
  #
  # @return [Hash<Symbol,Object>]
  attr_accessor :options

  # @!method to_io
  #   Used by Kernel.select
  #   @return [IO]
  def_delegator :@socket, :to_io, :to_io

  # @param socket [IO] An already-connected socket.
  # @param options [Hash] Options (see {#options}).
  def initialize( socket, options = {} )
    @socket  = socket
    @options = options
  end

  # Delegate to @sock
  def method_missing(meth, *args, &block)
    if @socket.respond_to?(meth)
      self.class.translate_errors do
        # not send() because that sends a packet.  =)
        @socket.__send__(meth, *args, &block)
      end
    else
      super
    end
  end

  def respond_to_missing?(meth, include_private=false)
    @socket.respond_to?(meth, include_private)
  end

end
