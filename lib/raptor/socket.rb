require 'forwardable'

# A basic class for specific transports to inherit from. Analogous to
# stdlib's BasicSocket
class Raptor::Socket
  extend Forwardable

  require 'raptor/socket/error'
  require 'raptor/socket/switch_board'
  require 'raptor/socket/tcp'
  require 'raptor/socket/tcp_server'

  class << self

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
        begin
          # not send() because that sends a packet.  =)
          ::Socket.__send__(meth, *args, &block)
        rescue ::Errno::EPIPE, ::Errno::ECONNRESET => e
          raise Raptor::Socket::Error::BrokenPipe, e.to_s
        rescue ::Errno::ECONNREFUSED => e
          raise Raptor::Socket::Error::ConnectionRefused, e.to_s
        end
      else
        super
      end
    end

    def respond_to_missing?(meth, include_private=false)
      ::Socket.respond_to?(meth, include_private)
    end
  end

  # Configuration for this socket.
  #
  # @return [Hash<Symbol,Object>]
  attr_accessor :config

  # @param sock [IO] An already-connected socket
  # @param config [Hash] Configuration options. See {#config}
  def initialize(sock, config={})
    @sock = sock
    @config = config
  end

  # @!method to_io
  #   Used by Kernel.select
  #   @return [IO]
  def_delegator :@sock, :to_io, :to_io

  # Delegate to @sock
  def method_missing(meth, *args, &block)
    if @sock.respond_to?(meth)
      begin
        # not send() because that sends a packet.  =)
        @sock.__send__(meth, *args, &block)
      rescue ::Errno::EPIPE, ::Errno::ECONNRESET => e
        raise Raptor::Socket::Error::BrokenPipe, e.to_s
      rescue ::Errno::ECONNREFUSED => e
        raise Raptor::Socket::Error::ConnectionRefused, e.to_s
      end
    else
      super
    end
  end

  def respond_to_missing?(meth, include_private=false)
    @sock.respond_to?(meth, include_private)
  end

end
