require 'socket'

module Raptor
module Protocol::HTTP

#
# HTTP Client class.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Client

  # @param [Integer] Maximum open sockets.
  # @return [Integer] Maximum open sockets.
  attr_accessor :concurrency

  # @param  [Hash]  options Request options.
  # @option options [String] :address Address of the HTTP server.
  # @option options [Integer] :port (80) Port number of the HTTP server.
  def initialize( options = {} )
    options.each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    # Pretty reasonable amount.
    @concurrency = 20

    # Holds Request objects.
    @queue       = []

    # A socket starts in `:writes`, once the request is written it gets moved
    # to `:reads` -- at which point it stays there while the response is being
    # buffered. Once a full response is received the socket is closed and moved
    # to `:done`.
    @sockets = {
        # Socket => HTTP Request lookup
        lookup_request: {},

        # Sockets ready to read from.
        reads:          [],

        # Sockets ready to write to.
        writes:         [],

        # Sockets with errors.
        errors:         [],

        # Sockets which have finished (or errored).
        done:           []
    }

    # Response buffer.
    @pending_responses = Hash.new(
      # Do we have full headers?
      has_headers: false,

      # HTTP headers buffer.
      headers: '',

      # Response body buffer.
      body: ''
    )
  end

  #
  # Creates and {#queue queues} a {Request}.
  #
  # @param  [String]  url URL of the remote resource.
  # @param  [Hash]  options {Request} options.
  # @param  [Block] block Callback to be passed the {Response}.
  #
  # @return [Request] Queued {Request}.
  #
  # @see Request#initialize
  # @see Request#on_complete
  # @see #queue
  #
  def request( url, options = {}, &block )
    req = Request.new( options.merge( url: url ) )
    req.on_complete( &block ) if block_given?
    queue( req )
    req
  end

  #
  # Creates and {#queue queues} a GET {Request}.
  #
  # @param (see #request)
  # @return (see #request)
  #
  def get( url, options = {}, &block )
    request( url, options.merge( http_method: :get ), &block )
  end

  #
  # Creates and {#queue queues} a POST {Request}.
  #
  # @param (see #request)
  # @return (see #request)
  #
  def post( url, options = {}, &block )
    request( url, options.merge( http_method: :post ), &block )
  end

  # @return [Integer] The amount of {#queue queued} requests.
  def queue_size
    @queue.size
  end

  #
  # Queues a {Request}.
  #
  # @param  [Request] request
  # @return [Request] `request`
  #
  def queue( request )
    @queue << request
    request
  end
  alias :<< :queue

  # Runs the {#queue queued} {Request}.
  def run
    while @queue.any?

      # Get us some seeds.
      consume_requests

      while @sockets[:done].size != @sockets[:lookup_request].size
        reads, writes, errors = select( @sockets[:reads], @sockets[:writes], nil )

        errors.each do |socket|
          handle_error( socket )
        end

        reads.each do |socket|
          # Buffer/handle the response for the given socket.
          read( socket )

          # Fully utilize our socket allowance.
          consume_requests
        end

        writes.each do |socket|
          # Send the request for the given socket.
          write( socket )

          # Fully utilize our socket allowance.
          consume_requests
        end

      end
    end

    nil
  end

  # @return [Integer] Amount of open sockets.
  def open_socket_count
    open_sockets.size
  end

  private

  # @return [Array<Socket>] Sockets currently open.
  def open_sockets
    @sockets[:writes] + @sockets[:reads]
  end

  def handle_error( socket )
    [:reads, :writes].each { |state| @sockets[state].delete( socket ) }
    @sockets[:done] << socket
    nil
  end

  #
  # Writes the associated {Request} to `socket`.
  #
  # @param  [#write]  Writable IO object.
  #
  def write( socket )
    request        = @sockets[:lookup_request][socket]
    request_string = request.to_s

    # Send out the request, **all** of it.
    loop do
      begin
        bytes_written = socket.write( request_string )
      rescue Errno::ECONNREFUSED, Errno::EPIPE
        handle_response( request )
        @sockets[:done] << @sockets[:writes].delete( socket )
        return
      end

      break if bytes_written == request_string.size

      request_string = request_string[bytes_written..-1]
    end

    # Move it to the read list.
    @sockets[:reads] << @sockets[:writes].delete( socket )

    true
  end

  #
  # Reads/buffers a response from `socket` and calls the callback of the
  # associated request once the full response is received -- at which point it
  # also closes the socket.
  #
  # @param  [#gets]  Readable IO object.
  #
  # @return [true, nil]
  #   `true` if the response finished being buffered, `nil` otherwise.
  #
  def read( socket )
    response = @pending_responses[socket]

    if response[:has_full_headers]

      read_size = if response[:content_length]
                    response[:content_length] - response[:body].size
                  else
                    nil
                  end

      response[:body] << socket.gets( read_size ).to_s

      # Check to see if we're done.
      return if response[:body].size < response[:content_length]

      socket.close
      @sockets[:done] << @sockets[:reads].delete( socket )

      handle_response( @sockets[:lookup_request][socket], response )
      @pending_responses.delete( socket )
      return true
    end

    response[:headers] << socket.gets.to_s

    # Extract the content length, lets us know how of of the body, if any,
    # to read before we close the socket.
    response[:content_length] ||= find_content_length( response[:headers] )

    # If we hit a content-length of 0 we're done.
    if response[:content_length] == 0
      response[:has_full_headers] = true
      return
    end

    # Keep going until we get all the headers.
    return if !response[:headers].include?( "\r\n\r\n" )
    response[:has_full_headers] = true

    # Some of the body may have gotten into the headers' buffer, sort them out.
    response[:headers], response[:body] = response[:headers].split( "\r\n\r\n", 2 )
  end

  #
  # @note Respects the {#concurrency} limit.
  #
  # Consumes requests from the queue and adds write-sockets for them.
  #
  # @return [Integer] Amount of requests consumed.
  #
  def consume_requests
    added = 0

    (@concurrency - open_socket_count).times do
      return added if @queue.empty?
      q_request = @queue.pop

      socket = connect( q_request )
      next if !socket

      @sockets[:lookup_request][socket] = q_request
      @sockets[:writes] << socket

      added += 1
    end

    added
  end

  #
  # Opens up an non-blocking socket for the given `request`.
  #
  # @param  [Request]
  #
  # @return [Socket, nil]
  # Socket on success, `nil` on failure. On failure, the request callback will
  # be passed an empty response.
  #
  def connect( request, timeout = 10 )
    @address ||= {}

    host = request.parsed_url.host
    port = request.parsed_url.port

    address =  begin
      (@address["#{host}:#{port}"] ||= Socket.getaddrinfo( host, nil ))
    rescue Errno::ENOENT
      handle_response( request )
      return
    end

    socket = Socket.new( Socket.const_get( address[0][0] ), Socket::SOCK_STREAM, 0 )

    begin
      socket.connect_nonblock( Socket.pack_sockaddr_in( port, address[0][3] ) )
    rescue Errno::EINPROGRESS
    end

    socket
  end

  #
  # Extracts the content length from HTTP headers.
  #
  # @param  [String]  response  HTTP response.
  #
  # @return [Integer] Content-length value, `0` if there isn't one.
  #
  def find_content_length( response )
    return if !response.downcase.include?( 'content-length' )
    response.scan( /^content\-length:\s*(\d+)\s*$/i ).flatten.first.to_i
  end

  # @param  [Request] request Request whose callback is passed a parsed {Response}.
  # @param  [Hash]  response Response buffer data.
  def handle_response( request, response = {} )
    request.handle_response Response.parse( "#{response[:headers]}\r\n\r\n#{response[:body]}" )
  end

end

end
end
