require 'thread'
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

  # @return [Hash{Symbol=>Hash}]
  #   Request manipulators, and their options, to be run against each
  #   {#queue queued} request.
  attr_accessor :manipulators

  # @return [Hash]  Persistent storage for the manipulators..
  attr_accessor :datastore

  DEFAULT_OPTIONS = {
      concurrency:      20,
      user_agent:       "Raptor::HTTP/#{Raptor::VERSION}",
      timeout:          10,
      manipulators:     {}
  }.freeze

  # @param  [Hash]  options Request options.
  # @option options [Integer] :concurrency (20)
  #   Amount of open sockets at any given time.
  # @option options [String] :user_agent ('Raptor::HTTP/<Raptor::VERSION>')
  #   User-agent string to include in the requests.
  # @option options [Integer, Float] :timeout (10)
  #   Timeout in seconds.
  # @option options [Hash{Symbol=>Hash}] :manipulators
  #   Request manipulators and their options.
  #
  # @raise  Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
  #   On invalid manipulator options.
  def initialize( options = {} )
    DEFAULT_OPTIONS.merge( options ).each do |k, v|
      begin
        send( "#{k}=", try_dup( v ) )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, try_dup( v ) )
      end
    end

    validate_manipulators!( manipulators )

    # Holds Request objects.
    @queue = []

    # Persistent storage for request manipulators.
    @datastore = Hash.new { |h, k| h[k] = {} }

    reset_sockets
    reset_pending_responses
  end

  #
  # Updates the client {#manipulators} and perform and sanity check on their
  # options.
  #
  # @param  [Hash{String=>Hash}]  manipulators
  #   Manipulators and their options.
  #
  # @raise  Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
  def update_manipulators( manipulators )
    validate_manipulators!( manipulators )
    @manipulators.merge!( manipulators )
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
  # @option options [Hash, String]  :cookies
  #   Cookies as name=>pair values -- should already be escaped.
  #
  # @option options [Hash{Symbol=>Hash}]  :manipulators
  #   Manipulator names for keys and their options as their values.
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

    case options[:cookies]
      when Hash
        req.headers['Cookie'] =
            options[:cookies].map { |k, v| "#{k}=#{v}" }.join( ';' )
      when String
        req.headers['Cookie'] = options[:cookies]
    end

    return sync_request( req, options[:manipulators] || {} ) if options[:mode] == :sync

    req.on_complete( &block ) if block_given?

    queue( req, options[:manipulators] || {} )
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
  # @param  [Hash{Symbol=>Hash}]  manipulators
  #   Manipulator names for keys and their options as their values.
  # @return [Request] `request`
  #
  def queue( request, manipulators = {} )
    validate_manipulators!( manipulators )

    request.timeout ||= timeout

    @manipulators.merge( manipulators ).each do |manipulator, options|
      Request::Manipulators.process( manipulator, self, request, options )
    end

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

        if @sockets[:reads].any?
          # Use the lowest available timeout for #select.
          lowest_timeout =
              @sockets[:reads].map { |socket| @pending_responses[socket][:timeout] }.sort.first

          clock = Time.now
          res = select( @sockets[:reads], nil, @sockets[:reads], lowest_timeout )
          waiting_time = Time.now - clock

          # Adjust the timeouts for *all* sockets since they all benefited from
          # the #select waiting period which just elapsed.
          #
          # And this is the whole reason for keeping track of timeouts externally.
          @pending_responses.each do |_, pending_response|
            pending_response[:timeout] -= waiting_time
            pending_response[:timeout]  = 0 if pending_response[:timeout] < 0
          end

          # #select timed out, go digging.
          if !res
            # Find and handle the sockets which timed out.
            @sockets[:reads].each do |socket|
              if waiting_time >= @pending_responses[socket][:timeout]
                error = Raptor::Error::Timeout.new( 'Request timed-out.' )
                error.set_backtrace( caller )
                handle_error( @sockets[:lookup_request][socket], error, socket )
              end

              # Fill the available pool space.
              consume_requests
            end

          # #select didn't time out, yay!
          else

            # Handle sockets with errors -- like reset connections.
            if res[2].any?
              res[2].each do |socket|
                handle_error( @sockets[:lookup_request][socket], nil, socket )

                # Fill the available pool space.
                consume_requests
              end
            end

            # Handle sockets which are ready to be read.
            if res[0].any?
              res[0].each do |socket|
                # Buffer/handle the response for the given socket.
                read( socket )

                # Fill the available pool space.
                consume_requests
              end
            end
          end
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
  def sync_request( request, manipulators = {} )
    client = self.class.new(
        user_agent:       user_agent,
        timeout:          timeout
    )

    # The normal and sync clients should share these structures, that's why
    # we're not passing them via the initializer.
    client.manipulators = @manipulators
    client.datastore    = @datastore

    res = nil
    request.on_complete { |r| res = r }
    client.queue( request, manipulators )
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
    request_string = request.to_s.repack

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
    reset_timeout( socket )

    response = @pending_responses[socket]

    if response[:has_full_headers]
      headers = response[:parsed_headers]

      if headers['Transfer-Encoding'] == 'chunked'
        read_size = socket.gets.to_s[0...-CRLF.size]
        return if read_size.empty?

        if (read_size = read_size.to_i( 16 )) > 0
          response[:body] << socket.gets( read_size + CRLF.size ).to_s[0...read_size]
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

        has_body = headers['Content-length'] != '0'

        closed = false
        if has_body
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
        return if has_body && ((!read_size && !closed) || (response[:body].size < content_length))
      end

      handle_success( socket )
      return true
    end

    response[:headers] << socket.gets.to_s

    # Keep going until we get all the headers.
    return if !(response[:headers] =~ HEADER_SEPARATOR_PATTERN)
    response[:has_full_headers] = true

    # Perform some preliminary parsing to make our lives easier.
    response[:partial_response] = Response.parse( response[:headers] )
    response[:parsed_headers]   = response[:partial_response].headers

    # Some of the body may have gotten into the headers' buffer, sort them out.
    response[:headers], response[:body] = response[:headers].split( HEADER_SEPARATOR_PATTERN, 2 )

    # If there is no body to expect handle the response now.
    if response[:partial_response].headers['Content-length'] == '0' ||
        status_without_body?( response[:partial_response].code )
      handle_success( socket )
      return true
    end

    nil
  end

  def reset_timeout( socket )
    @pending_responses[socket][:timeout] = @sockets[:lookup_request][socket].timeout
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

  def self.reset
    connection_pool.each do |_, q|
      q.pop.close while !q.empty?
    end
    nil
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

    response_text = "#{response_data[:headers]}#{HEADER_SEPARATOR}#{response_data[:body]}"
    response = Response.parse( response_text )
    request  = @sockets[:lookup_request][socket]

    if response.keep_alive? && !response_data[:force_no_keep_alive]
      connection_pool[request.connection_id] << socket
    else
      socket.close
    end

    if response.code == 100 && request.continue?
      request = request.dup
      request.headers.delete 'expect'
      queue( request.dup )
      return
    end

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
    @pending_responses = Hash.new do |h, socket|
      h[socket] = {
          # Do we have full headers?
          has_full_headers: false,

          # HTTP headers buffer.
          headers: '',

          # Response body buffer.
          body: '',

          # We use this to keep track of individual socket timeouts.
          timeout: @sockets[:lookup_request][socket].timeout
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

  def status_without_body?( status_code )
    status_code.to_s.start_with?( '1' ) || [204, 304].include?( status_code.to_i )
  end

  def validate_manipulators!( manipulators )
    Request::Manipulators.validate_batch_options!( manipulators, self )
  end

  def validate_manipulators( manipulators )
    Request::Manipulators.validate_batch_options( manipulators, self )
  end

  def try_dup( value )
    value.dup rescue value
  end

end

end
end
