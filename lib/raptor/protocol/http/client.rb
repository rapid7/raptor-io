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

  #
  # @param  [Hash]  options Request options.
  # @option options [String] :address Address of the HTTP server.
  # @option options [Integer] :port (80) Port number of the HTTP server.
  #
  def initialize( options = {} )
    options.each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    @concurrency = 20
    @queue       = []
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
    sockets = {
        lookup_request: {},
        reads:          [],
        writes:         [],
        errors:         [],
        done:           []
    }

    responses = {}
    while @queue.any?

      # Get us some seed sockets.
      add_sockets( @concurrency, sockets )

      while sockets[:done].size != sockets[:lookup_request].size

        # Open up new sockets to fill the concurrency allowance.
        add_sockets( @concurrency - sockets[:writes].size, sockets )

        reads, writes, errors = select( sockets[:reads], sockets[:writes], nil )

        sockets[:done] |= errors

        reads.each do |socket|
          responses[socket]               ||= {}
          # Do we have full headers?
          responses[socket][:has_headers] ||= false
          # HTTP headers buffer.
          responses[socket][:headers]     ||= ''
          # Response body buffer.
          responses[socket][:body]        ||= ''

          response = responses[socket]

          if response[:has_full_headers]

            read_size = if response[:content_length]
                          response[:content_length] - response[:body].size
                        else
                          nil
                        end

            response[:body] << socket.gets( read_size ).to_s

            # Check to see if we're done.
            next if response[:body].size < response[:content_length]

            socket.close
            sockets[:done] << sockets[:reads].delete( socket )

            handle_response( sockets[:lookup_request][socket], response )
            next
          end

          response[:headers] << socket.gets.to_s

          # Extract the content length, lets us know how of of the body, if any,
          # to read before we close the socket.
          response[:content_length] ||= find_content_length( response[:headers] )

          # If we hit a content-length of 0 we're done.
          if response[:content_length] == 0
            response[:has_full_headers] = true
            next
          end

          # Keep going until we get all the headers.
          next if !response[:headers].include?( "\r\n\r\n" )
          response[:has_full_headers] = true

          # Some of the body may have gotten into the headers' buffer, sort them out.
          response[:headers], response[:body] = response[:headers].split( "\r\n\r\n", 2 )
        end

        writes.each do |socket|
          # Send out the request.
          socket.write( sockets[:lookup_request][socket].to_s )

          # Move it to the read list.
          sockets[:reads] << sockets[:writes].delete( socket )
        end

      end
    end

    # Callbacks may have added new requests to the queue.
    run if !@queue.empty?

    nil
  end

  private

  def add_sockets( amount, sockets )
    return if amount <= 0

    amount.times do
      break if @queue.empty?
      q_request = @queue.pop

      socket = connect( q_request )
      sockets[:lookup_request][socket] = q_request
      sockets[:writes] << socket
    end

    sockets
  end

  def connect( request, timeout = 10 )
    @address ||= {}

    host = request.parsed_url.host
    port = request.parsed_url.port

    address = (@address["#{host}:#{port}"] ||= Socket.getaddrinfo( host, nil ))

    socket = Socket.new( Socket.const_get( address[0][0] ), Socket::SOCK_STREAM, 0 )

    begin
      socket.connect_nonblock( Socket.pack_sockaddr_in( port, address[0][3] ) )
    rescue Errno::EINPROGRESS
    end

    socket
  end

  def find_content_length( response )
    return if !response.downcase.include?( 'content-length' )
    response.scan( /^content\-length:\s*(\d+)\s*$/i ).flatten.first.to_i
  end

  def handle_response( request, response )
    request.handle_response Response.parse( "#{response[:headers]}\r\n\r\n#{response[:body]}" )
  end

end

end
end
