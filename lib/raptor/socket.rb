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

  def self.select(readers=[], writers=[], exceptors=[], timeout=nil)
    readers ||= []
    writers ||= []
    exceptors ||= []

    selectable_readers = readers.dup

    readers_with_data = []

    selectable_readers.delete_if do |reader|
      begin
        byte = reader.read_nonblock(1)
      rescue IO::WaitReadable
        # then this thing needs to go through the actual select
        false
      rescue EOFError
        # Then this thing has an empty read buffer and there's no more
        # on the wire.
        readers_with_data << reader
        true
      else
        # then this thing has data already in its read buffer and we can
        # skip the real select for this guy
        reader.ungetc(byte)
        readers_with_data << reader
        true
      end
    end

    real = if selectable_readers.any? || writers.any? || exceptors.any?
             IO.select(selectable_readers, writers, exceptors, timeout)
           else
             [[], [], []]
           end

    # Add in any sockets that have data buffered and ready to read
    real[0] |= readers_with_data
    pp real

    return real
  end

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

  # @!method read
  #   (see ::IO#read)
  #   @param length [Fixnum] (nil)
  #   @param buffer [String] (nil)
  #   @return [String,nil]
  def_delegator :@socket, :read

  # @!method write
  #   @return [Fixnum]
  def_delegator :@socket, :write

  # @!method readpartial
  def_delegator :@socket, :readpartial

  # @!method read_nonblock
  def_delegator :@socket, :read_nonblock

=begin
  # Delegate to @sock
  def method_missing(meth, *args, &block)
    if @socket.respond_to?(meth)
      $stderr.puts("#{self.class}#method_missing(#{meth})")
      self.class.translate_errors do
        # not send() because that sends a packet.  =)
        @socket.__send__(meth, *args, &block)
      end
    else
      super
    end
  end
=end

  def respond_to_missing?(meth, include_private=false)
    @socket.respond_to?(meth, include_private)
  end

  def ssl?
    true
  end

end
