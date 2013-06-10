require 'socket'
require 'base64'

module Raptor
module Protocol::HTTP

#
# HTTP Client class.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Client

  # @return [Integer, Float] Timeout in seconds.
  attr_accessor :timeout

  # @return [Integer] Maximum open sockets.
  attr_accessor :concurrency

  # @return [String]  User-agent string to use.
  attr_accessor :user_agent

  # @return [Integer] Maximum redirection responses to follow.
  attr_accessor :max_redirections

  # @return [String]  User name to authenticate as.
  attr_accessor :username

  # @return [String]  Password to use for authentication.
  attr_accessor :password

  DEFAULT_OPTIONS = {
      concurrency:      20,
      user_agent:       "Raptor::HTTP/#{Raptor::VERSION}",
      max_redirections: 5, # RFC says 5 max.
      username:         nil,
      password:         nil,
      timeout:          10
  }

  # @param  [Hash]  options Request options.
  # @option options [Integer] :concurrency (20)
  #   Amount of open sockets at any given time.
  # @option options [String] :user_agent ('Raptor::HTTP/<Raptor::VERSION>')
  #   User-agent string to include in the requests.
  def initialize( options = {} )
    DEFAULT_OPTIONS.merge( options ).each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    if [@username.to_s, @password.to_s].reject( &:empty? ).size == 1
      fail ArgumentError, 'Both \':username\' and \':password\' options are required.'
    end

    # Holds Request objects.
    @queue = []

    reset_sockets
    reset_pending_responses
  end

  #
  # Creates and {#queue queues} a {Request}.
  #
  # @param  [String]  url URL of the remote resource.
  # @param  [Hash]  options {Request} options with the following extras:
  # @option options [Symbol]  :mode (:async)
  #   Mode to use for the request, available options are:
  #
  #   * `:async`  -- Adds the request to the queue.
  #   * `:sync`  -- Performs the request in a blocking manner and returns the
  #     {Response}.
  #
  # @param  [Block] block Callback to be passed the {Response}.
  #
  # @return [Request, Response]
  #   Queued {Request} when in `:async` `:mode`, {Response} when in `:sync`
  #   `:mode`.
  #
  # @see Request#initialize
  # @see Request#on_complete
  # @see #queue
  #
  def request( url, options = {}, &block )
    options = options.dup
    options[:timeout] ||= @timeout

    req = Request.new( options.merge( url: url ) )

    req.headers['User-Agent'] = @user_agent if !@user_agent.to_s.empty?

    if @username && @password
      req.headers['Authorization'] = "Basic #{Base64.encode64("#{@username}:#{@password}").chomp}"
    end

    return sync_request( req ) if options[:mode] == :sync

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

        # Read sockets need individual timeouts (because requests have individual
        # timeouts) so they get their own #select calls.
        @sockets[:reads].dup.each do |socket|
          request = @sockets[:lookup_request][socket]
          res = select( [socket], nil, [socket], request.timeout )

          # We either reached the timeout or the connection was reset.
          if !res
            error = Raptor::Error::Timeout.new( 'Request timed-out.' )
            error.set_backtrace( caller )
            handle_error( request, error, socket )
            next
          end

          if res[2].any?
            handle_error( request, nil, socket )
            next
          end

          # Buffer/handle the response for the given socket.
          read( socket )

          # Fully utilize our socket allowance.
          consume_requests
        end

        next if @sockets[:writes].empty?

        _, writes, errors = select( nil, @sockets[:writes], @sockets[:writes] )

        errors.each do |socket|
          handle_error( @sockets[:lookup_request][socket], nil, socket )
        end

        writes.each do |socket|
          # Send the request for the given socket.
          write( socket )

          # Fully utilize our socket allowance.
          consume_requests
        end

      end
    end

    reset_sockets
    reset_pending_responses

    nil
  end

  # @return [Integer] Amount of open sockets.
  def open_socket_count
    open_sockets.size
  end

  private

  # @param  [Request] request Request to perform in blocking mode.
  # @return [Response]  HTTP response.
  def sync_request( request )
    client = self.class.new(
        max_redirections: max_redirections,
        user_agent:       user_agent,
        timeout:          timeout
    )

    res = nil
    request.on_complete { |r| res = r }
    client.queue( request )
    client.run

    raise res.error if res.error

    res
  end

  # @return [Array<Socket>] Sockets currently open.
  def open_sockets
    @sockets[:writes] + @sockets[:reads]
  end

  #
  # Writes the associated {Request} to `socket`.
  #
  # @param  [#write]  socket  Writable IO object.
  #
  def write( socket, retry_on_fail = true )
    request        = @sockets[:lookup_request][socket]
    request_string = request.to_s

    # Send out the request, **all** of it.
    loop do
      begin
        bytes_written = socket.write( request_string )
      # All hope is lost.
      rescue Errno::ECONNREFUSED => e
        error = Protocol::Error::ConnectionRefused.new( e.to_s )
        error.set_backtrace( e.backtrace )
        handle_error( request, error, socket )
        return

      # Rhe connection has been closed so retry but only if the request is
      # idempotent.
      rescue Errno::EPIPE, Errno::ECONNRESET => e
        if request.idempotent? && retry_on_fail
          @sockets[:writes].delete( socket )

          fresh_socket = refresh_connection( socket )
          @sockets[:writes] << fresh_socket
          return write( fresh_socket, false )
        else
          error = Protocol::Error::BrokenPipe.new( e.to_s )
          error.set_backtrace( e.backtrace )
          handle_error( request, error, socket )
        end
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
  # @param  [#gets] socket  Readable IO object.
  #
  # @return [true, nil]
  #   `true` if the response finished being buffered, `nil` otherwise.
  #
  def read( socket )
    response = @pending_responses[socket]

    if response[:has_full_headers]
      headers = (response[:parsed_headers] ||= Response.parse( response[:headers] ).headers)

      if headers['Transfer-Encoding'] == 'chunked'
          read_size = socket.gets.to_s[0...-CRLF_SIZE]
          return if read_size.empty?

          if (read_size = read_size.to_i( 16 )) > 0
            response[:body] << socket.gets( read_size + CRLF_SIZE ).to_s[0...read_size]
            return
          end
      else
        # A Content-Type is not strictly necessary, the end of the response body
        # can also be signaled by the server closing the connection. That's why
        # the following code is so ugly.

        read_size = nil
        if (content_length = headers['Content-length'].to_i) > 0
          read_size = content_length - response[:body].size
        end

        closed = false
        if headers['Content-length'] != '0'
          begin
            if (line = socket.gets( *[read_size].compact ))
              response[:body] << line
            else
              raise Errno::ECONNRESET
            end
          rescue Errno::ECONNRESET
            closed = true
            response[:force_no_keep_alive] = true
          end
        end

        # Return back to the #select loop if there's more data to be read
        # and wait for our next turn.
        return if (!headers['Content-length'] && !read_size && !closed) || (response[:body].size < content_length)
      end

      handle_success( socket )
      return true
    end

    response[:headers] << socket.gets.to_s

    # Keep going until we get all the headers.
    return if !response[:headers].include?( HEADER_SEPARATOR )
    response[:has_full_headers] = true

    headers = Response.parse( response[:headers] ).headers

    # If we hit a content-length of 0, we're done.
    # Directly call the #read handle to take care of the response.
    return read( socket ) if headers['Content-length'] == '0'

    # Some of the body may have gotten into the headers' buffer, sort them out.
    response[:headers], response[:body] = response[:headers].split( HEADER_SEPARATOR, 2 )

    nil
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

      socket = connection_for_request( q_request )
      next if !socket

      @sockets[:lookup_request][socket] = q_request
      @sockets[:writes] << socket

      added += 1
    end

    added
  end

  # @param  [Request] request
  def connection_for_request( request )
    # If the request is idempotent grab a pool connection as we can risk a retry
    # in case it has been closed...
    socket =  if request.idempotent?
                # If there's an idling connection to that server, use it instead of opening
                # a new one.
                if connection_pool[request.connection_id].empty?
                  connect( request )
                else
                  connection_pool[request.connection_id].pop
                end

              # ...otherwise establish and use a new connection (and make room
              # in the queue).
              else
                if !connection_pool[request.connection_id].empty?
                  connection_pool[request.connection_id].pop.close
                end
                connect( request )
              end

    @sockets[:done].delete( socket )
    socket
  end

  def self.connection_pool
    @connection_pool ||= Hash.new do |h, k|
      h[k] = Queue.new
    end
  end
  def connection_pool
    self.class.connection_pool
  end

  # Opens up an non-blocking socket for the given `request`.
  #
  # @param  [Request] request
  def connect( request )
    @address ||= {}

    host = request.parsed_url.host
    port = request.parsed_url.port

    address =  begin
      (@address[request.connection_id] ||= Socket.getaddrinfo( host, nil ))
    rescue Errno::ENOENT => e
      error = Protocol::Error::CouldNotResolve.new( e.to_s )
      error.set_backtrace( e.backtrace )
      handle_error( request, error, nil )
      return
    end

    socket = Socket.new( Socket.const_get( address[0][0] ), Socket::SOCK_STREAM, 0 )

    begin
      socket.connect_nonblock( Socket.pack_sockaddr_in( port, address[0][3] ) )
    rescue Errno::EINPROGRESS
      if select( nil, [socket], nil, @timeout ).nil?
        error = Protocol::Error::HostUnreachable.new
        error.set_backtrace( caller )
        handle_error( request, error, nil )
        return
      end
    end

    socket
  end

  def handle_success( socket )
    response_data = @pending_responses.delete( socket )
    @sockets[:done] << @sockets[:reads].delete( socket )

    response = Response.parse( "#{response_data[:headers]}#{HEADER_SEPARATOR}#{response_data[:body]}" )
    request  = @sockets[:lookup_request][socket]

    if response.keep_alive? && !response_data[:force_no_keep_alive]
      connection_pool[request.connection_id] << socket
    else
      socket.close
    end

    @redirections ||= Hash.new([])

    if response.redirect?
      if @redirections[request].size < max_redirections
        (@redirections[request] ||= []) << response

        request = request.dup

        # RFC says the Location URI must be a full absolute URL however not
        # all webapps respect that.
        request.url = request.parsed_url.merge( response.headers['Location'] ).to_s

        queue( request.dup )
        return
      else
        @redirections.delete( request )
      end
    end

    response.redirections = @redirections[request]

    request.handle_response response
  end

  def handle_error( request, error = nil, socket = nil )
    if socket
      socket.close
      [:reads, :writes].each { |state| @sockets[state].delete( socket ) }
      @sockets[:done] << socket
    end

    response = Response.new( error: error )
    request.handle_response response
  end

  def reset_sockets
    # A socket starts in `:writes`, once the request is written it gets moved
    # to `:reads`, at which point it stays there while the response is being
    # buffered. Once a full response is received, and keep-alive is disabled, the
    # socket is closed and moved to `:done`.
    #
    # If keep-alive is enabled, the connection is moved to `:done` without
    # first being closed and will be reused appropriately, at which point it
    # will be removed from `:done` and start all over.
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
  end

  def reset_pending_responses
    # Response buffer.
    @pending_responses = Hash.new do |h, k|
      h[k] = {
          # Do we have full headers?
          has_full_headers: false,

          # HTTP headers buffer.
          headers: '',

          # Response body buffer.
          body: ''
      }
    end
  end

  def refresh_connection( socket )
    request      = @sockets[:lookup_request].delete( socket )
    fresh_socket = connection_for_request( request )

    @sockets[:lookup_request][fresh_socket] = request
    fresh_socket
  ensure
    socket.close
    @pending_responses.delete( socket )
    [:reads, :writes].each { |state| @sockets[state].delete( socket ) }
  end

end

end
end
