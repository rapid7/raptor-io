
# A basic class for specific transports to inherit from. Analogous to
# stdlib's BasicSocket
class Raptor::Socket

  require 'raptor/socket/error'
  require 'raptor/socket/switch_board'
  require 'raptor/socket/tcp'
  require 'raptor/socket/tcp_server'

  # @param sock [IO]
  def initialize(sock)
    @sock = sock
  end

  # Used by Kernel.select
  def to_io
    @sock
  end

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
