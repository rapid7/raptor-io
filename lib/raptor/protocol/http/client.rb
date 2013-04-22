require 'thread' # we want Queue

module Raptor
module Protocol::HTTP

#
# HTTP Client class.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Client

  # @return [String]  Address of the HTTP server.
  attr_reader :address

  # @return [Integer]  Port number of the HTTP server.
  attr_reader :port

  #
  # @param  [Hash]  options Request options.
  # @option options [String] :address Address of the HTTP server.
  # @option options [Integer] :port (80) Port number of the HTTP server.
  # @option options [Integer] :port (80) Port number of the HTTP server.
  #
  def initialize( options )
    options.each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    fail ArgumentError, "Missing ':address' option." if !@address

    @port ||= 80
    @queue  = Queue.new
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
    fail 'Not implemented.'
  end

end

end
end
