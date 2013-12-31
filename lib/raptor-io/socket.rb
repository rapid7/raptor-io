require 'forwardable'
require 'raptor-io/ruby'

# A basic class for specific transports to inherit from. Analogous to
# stdlib's BasicSocket
class RaptorIO::Socket
  extend Forwardable

  require 'raptor-io/socket/error'
  require 'raptor-io/socket/switch_board'
  require 'raptor-io/socket/tcp'
  require 'raptor-io/socket/tcp/ssl'
  require 'raptor-io/socket/tcp_server'
  require 'raptor-io/socket/tcp_server/ssl'

  # Like IO.select, but smarter
  #
  # OpenSSL does its own buffering which can result in a consumed TCP
  # buffer, leading `IO.select` to think that the SSLSocket has no more
  # data to provide, when that's not the case, effectively making
  # `IO.select` block forever, even though the SSLSocket's buffer has
  # not yet been consumed.
  #
  # We work around this by attempting a non-blocking read of one byte on
  # each of the `read_array`, and putting the byte back with
  # `Socket#ungetc` if it worked, or running it through the the real
  # `IO.select` if it doesn't.
  #
  # @see http://bugs.ruby-lang.org/issues/8875
  # @see http://jira.codehaus.org/browse/JRUBY-6874
  # @param read_array [Array] (see IO.select)
  # @param write_array [Array] (see IO.select)
  # @param error_array [Array] (see IO.select)
  # @param timeout [Fixnum,nil] (see IO.select)
  #
  # @return [Array] An Array containing three arrays of IO objects that
  #   are ready for reading, ready for writing, or have pending errors,
  #   respectively.
  # @return [nil] If optional `timeout` is given and `timeout` seconds
  #   elapse before any data is available
  def self.select(read_array=[], write_array=[], error_array=[], timeout=nil)
    read_array  ||= []
    write_array ||= []
    error_array ||= []

    readers_with_data = []

    selectable_readers = read_array.dup.delete_if do |reader|
      begin
        # If this socket doesn't have a read_nonblock method, then it's
        # a server of some kind and we have to run it through the real
        # select to see if it can {TCPServer#accept accept}.
        next false unless reader.respond_to? :read_nonblock

        byte = reader.read_nonblock(1)
      rescue IO::WaitReadable, IO::WaitWritable
        # Then this thing needs to go through the real select to be able
        # to tell if it has data.
        #
        # Note that {IO::WaitWritable} is needed here because OpenSSL
        # sockets can block for writing when calling `read*` because of
        # session renegotiation and the like.
        false
      rescue EOFError
        # Then this thing has an empty read buffer and there's no more
        # on the wire. We mark it as having data so a subsequent
        # read or read_nonblock will raise EOFError appropriately.
        readers_with_data << reader
        true
      else
        # Then this thing has data already in its read buffer and we can
        # skip the real select for it.
        reader.ungetc(byte)
        readers_with_data << reader
        true
      end
    end

    if readers_with_data.any?
      if selectable_readers.any? || write_array.any? || error_array.any?
        #$stderr.puts(" ----- Selecting readers:")
        #pp selectable_readers
        # Then see if anything has data right now by using a 0 timeout
        r,w,e = IO.select(selectable_readers, write_array, error_array, 0)

        real = [
          readers_with_data | (r || []),
          w || [],
          e || []
        ]
      else
        # Then there's nothing selectable and we can just return stuff
        # that has buffered data
        real = [ readers_with_data, [], [] ]
      end
    else
      # Then wait the given timeout, regardless of whether the arrays
      # are empty
      real = IO.select(read_array, write_array, error_array, timeout)
    end

    #$stderr.puts '------ RaptorIO::Socket.select result ------'
    #pp real
    return real
  end

  class << self

    # Captures Ruby exceptions and converts them to RaptorIO Errors.
    #
    # @param  [Block] block Block to run.
    def translate_errors( &block )
      block.call
    rescue ::Errno::EPIPE, ::Errno::ECONNRESET => e
      raise RaptorIO::Socket::Error::BrokenPipe, e.to_s
    rescue ::Errno::ECONNREFUSED => e
      raise RaptorIO::Socket::Error::ConnectionRefused, e.to_s
    end

    # Delegates to `::Socket.getaddrinfo`.
    def getaddrinfo( *args )
      begin
        ::Socket.getaddrinfo( *args )
      # OSX raises SocketError.
      rescue ::SocketError, ::Errno::ENOENT => e
        raise RaptorIO::Socket::Error::CouldNotResolve.new( e.to_s )
      end
    end

    # Delegate to Ruby Socket.
    def method_missing(meth, *args, &block)
      #$stderr.puts("Socket.method_missing(#{meth}, #{args.inspect}")
      if ::Socket.respond_to?(meth)
        translate_errors do
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

  # @!method closed?
  def_delegator :@socket, :closed?, :closed?

  # @!method close
  def_delegator :@socket, :close, :close

  # Whether this socket is an SSL stream.
  def ssl?
    false
  end

end
