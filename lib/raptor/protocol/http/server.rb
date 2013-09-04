require 'logger'

module Raptor
module Protocol::HTTP

# HTTP Server class.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Server

  # IO#listen backlog, 5 seems to be the default setting in a lot of
  # implementations.
  LISTEN_BACKLOG = 5

  DEFAULT_OPTIONS = {
      address:      '0.0.0.0',
      port:         4567,
      request_mtu:  512,
      response_mtu: 512,
      timeout:      10,
      logger:       ::Logger.new( STDOUT ),
      logger_level: Logger::INFO
  }.freeze

  # @return [String]  Address of the server.
  attr_reader :address

  # @return [Integer]  Port number of the server.
  attr_reader :port

  # @return [Integer]  MTU for reading request bodies.
  attr_reader :request_mtu

  # @return [Integer]  MTU for sending responses.
  attr_reader :response_mtu

  # @return [Integer]  Configured connection timeout.
  attr_reader :timeout

  # @return [Integer]  Amount of timed out connections.
  attr_reader :timeouts

  # @param  [Hash]  options
  # @option options [String] :address ('0.0.0.0')
  #   Address to bind to.
  # @option options [Integer] :port (4567)
  #   Port number to listen on.
  # @option options [Integer] :request_mtu (512)
  #   Buffer size for request reading -- only applies to requests with a
  #   Content-Length header.
  # @option options [Integer] :response_mtu (512)
  #   Buffer size for response transmission -- helps keep the server responsive
  #   while transmitting large responses.
  # @option options [#debug, #info, #warn, #error, #fatal ] :logger (Logger.new( STDOUT ))
  #   Timeout in seconds.
  # @option options [Integer] :logger_level (Logger::INFO)
  #   Level of message severity for the `:logger`.
  # @option options [Integer, Float] :timeout (10)
  #   Timeout (in seconds) for incoming requests.
  #
  # @param  [#call] handler
  #   Handler to be passed each {Request} and populate an empty {Response}
  #   object.
  def initialize( options = {}, &handler )
    DEFAULT_OPTIONS.merge( options ).each do |k, v|
      begin
        send( "#{k}=", try_dup( v ) )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, try_dup( v ) )
      end
    end

    @logger.level = @logger_level if @logger

    @sockets = {
        # Sockets ready to read from.
        reads:       [],

        # Sockets ready to write to.
        writes:      [],

        # Socket => Addrinfo
        client_info: {}
    }

    # In progress/buffered requests.
    @pending_requests = Hash.new do |h, socket|
      h[socket] = {
          # Buffered raw text request.
          buffer:         '',

          # HTTP::Headers, parsed when in the :buffer.
          headers:        nil,

          # Amount of the request body read, buffered to improve responsiveness
          # when handling large requests based on the :request_mtu option.
          body_bytes_read: 0,

          timeout:         @timeout
      }
    end

    # In progress/buffered responses.
    @pending_responses = Hash.new do |h, socket|
      h[socket] = {
          # HTTP::Response object to transmit.
          object:     nil,

          # Amount of HTTP::Response#to_s already sent, we buffer it for
          # performance reasons based on the :response_mtu option.
          bytes_sent: 0
      }
    end

    @timeouts = 0
    @stop     = false
    @running  = false

    @handler = handler
  end

  # Starts the server.
  def run
    return if @server

    @server  = listen
    synchronize { @running = true }

    while !stop?
      clock = Time.now
      sockets = select( [@server] | @sockets[:reads], @sockets[:writes],
                        open_sockets, @timeout )
      waiting_time = Time.now - clock

      # Adjust the timeouts for *all* sockets.
      @pending_requests.each do |_, pending_request|
        pending_request[:timeout] -= waiting_time
        pending_request[:timeout]  = 0 if pending_request[:timeout] < 0
      end

      # One or more sockets timed out, find them and KILL them! Muahahaha!
      if !sockets
        @sockets[:reads].each do |socket|
          # Close the socket if the client has exceeded their allotted time to
          # make contact.
          next if waiting_time < @pending_requests[socket][:timeout]

          close socket
          @timeouts += 1

          log 'Timeout', :debug, socket
        end

        next
      end

      # Go through the sockets which are available for reading.
      sockets[0].each do |socket|
        # Read and move to the next one if there are no new clients.
        if socket != @server
          read socket
          next
        end

        client, client_addrinfo = @server.accept_nonblock

        @sockets[:client_info][client] = client_addrinfo
        @sockets[:reads] << client

        log 'Connected', :debug, client
      end

      # Handle sockets which are ready to be written to.
      sockets[1].each do |socket|
        write socket
      end

      # Close sockets with errors.
      sockets[2].each do |socket|
        log 'Connection error', :error, socket
        close socket
      end
    end

    synchronize { @running = false }
  end

  def run_nonblock
    ex = nil
    Thread.new {
      begin
        run
      rescue => e
        synchronize { @running = true }
        ex = e
      end
    }
    sleep 0.1 while !running?

    if ex
      @running = false
      raise ex
    end
  end

  def running?
    synchronize { @running }
  end

  # Shuts down the server.
  def stop
    return if !@server

    synchronize { @stop = true }
    sleep 0.1 while running?

    close @server
    @server = nil

    open_sockets.each { |socket| close socket }

    true
  end

  def url
    "http://#{address}:#{port}/"
  end

  private

  def reset_timeout( socket )
    @pending_requests[socket][:timeout] = @timeout
  end

  def stop?
    synchronize { @stop }
  end

  def open_sockets
    @sockets[:reads] | @sockets[:writes]
  end

  def listen
    server = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
    server.setsockopt( Socket::Option.bool( :INET, :SOCKET, :REUSEADDR, true ) )
    server.bind( Socket.sockaddr_in( @port, @address ) )
    server.listen( LISTEN_BACKLOG )

    log "Listening on #{@address}:#{@port}."

    server
  end

  def read( socket )
    reset_timeout( socket )

    if (headers = @pending_requests[socket][:headers])
      if (content_length = headers['content-length'])
        content_length = content_length.to_i
        remaining_ct   = content_length - @pending_requests[socket][:body_bytes_read]
        read_size      = [remaining_ct, @request_mtu].min

        @pending_requests[socket][:buffer]          << socket.read( read_size )
        @pending_requests[socket][:body_bytes_read] += read_size

        return if content_length != @pending_requests[socket][:body_bytes_read]
      end

      handle_read_request( socket )
      return
    end

    @pending_requests[socket][:buffer] << socket.gets.to_s
    return if !(@pending_requests[socket][:buffer] =~ HEADER_SEPARATOR_PATTERN)

    @pending_requests[socket][:headers] ||=
        Request.parse( @pending_requests[socket][:buffer] ).headers
    return if @pending_requests[socket][:headers].include?( 'content-length' )

    handle_read_request( socket )
  end

  def handle_read_request( socket )
    request = Request.parse( @pending_requests.delete( socket )[:buffer] )
    @pending_responses[socket][:object] = handle_request( request )
    @sockets[:writes] << @sockets[:reads].delete( socket )
  end

  def handle_request( request )
    response = Response.new( request: request )

    if @handler
      @handler.call( request, response )
    else
      response.code    = 418
      response.message = "I'm a teapot"
      response.body    = request.body
    end

    response
  end

  def write( socket )
    response   = @pending_responses[socket][:object]
    bytes_sent = @pending_responses[socket][:bytes_sent]

    orig_response_string = response.to_s.repack
    response_string      = orig_response_string[bytes_sent..-1]

    if response_string.size > @response_mtu
      response_string = response_string[0...@response_mtu]
    end

    begin
      @pending_responses[socket][:bytes_sent] += socket.write( response_string )
    rescue IOError
      @pending_responses.delete( socket )
      close( socket )
      return
    end

    return if @pending_responses[socket][:bytes_sent] != orig_response_string.size

    @pending_responses.delete( socket )
    request = response.request

    log "#{request.http_method.upcase} #{request.resource} #{response.code}", :debug, socket

    if request.keep_alive?
      @sockets[:reads] << @sockets[:writes].delete( socket )
    else
      close( socket )
    end
  end

  def close( socket )
    @sockets[:reads].delete( socket )
    @sockets[:writes].delete( socket )
    @sockets[:client_info].delete( socket )
    socket.close
  end

  def synchronize( &block )
    (@mutex ||= Mutex.new).synchronize( &block )
  end

  def log( message, severity = :info, socket = nil )
    return if !@logger

    if socket && @sockets[:client_info].include?( socket )
      message += " [#{@sockets[:client_info][socket].inspect_sockaddr}]"
    end

    @logger.send severity, message
  end

  def try_dup( value )
    value.dup rescue value
  end

end

end
end
