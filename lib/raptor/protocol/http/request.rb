module Raptor
module Protocol::HTTP

#
# HTTP Request.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Request < PDU

  # Acceptable response callback types.
  CALLBACK_TYPES = [:on_complete, :on_failure, :on_success]

  # @return [Symbol]  HTTP method.
  attr_reader :http_method

  # @return [Hash]  Request parameters.
  attr_reader :parameters

  #
  # @note This class' options are in addition to {PDU#initialize}.
  #
  # @param  [Hash]  options Request options.
  # @option options [Symbol, String] :http_method HTTP method to use.
  # @option options [Hash] :parameters
  #   Parameters to send. If performing a GET request and the URL has parameters
  #   of its own they will be merged and overwritten.
  #
  # @see PDU#initialize
  # @see #parameters=
  # @see #http_method=
  #
  def initialize( options = {} )
    super( options )

    @callbacks = CALLBACK_TYPES.inject( {} ) { |h, type| h[type] = []; h }

    self.parameters  ||= {}
    self.http_method ||= :get
  end

  #
  # @note All keys and values will be recursively converted to strings.
  #
  # Sets request parameters.
  #
  # @param  [Hash]  params
  #   Parameters to assign to this request.
  #   If performing a GET request and the URL has parameters of its own they
  #   will be merged and overwritten.
  #
  # @return [Hash]  Normalized parameters.
  #
  def parameters=( params )
    @parameters = params.stringify
  end

  # @return [Hash] Parameters to be used for the query part of the resource.
  def query_parameters
    query = parsed_url.query
    if !query
      return http_method == :get ? parameters : {}
    end

    qparams = query.split( '&' ).inject({}) do |h, pair|
      k, v = pair.split('=', 2)
      h.merge( URI.decode(k) => URI.decode(v) )
    end
    return qparams if http_method != :get

    qparams.merge( parameters )
  end

  #
  # @note Method will be normalized to a lower-case symbol.
  #
  # Sets the request HTTP method.
  #
  # @param  [#to_s] http_verb HTTP method.
  #
  # @return [Symbol]  HTTP method.
  #
  def http_method=( http_verb )
    @http_method = http_verb.to_s.downcase.to_sym
  end

  # @return [String]
  #   String representation of the request, ready for HTTP transmission.
  def to_s
    fail 'Not implemented.'
  end

  CALLBACK_TYPES.each do |type|
    define_method type, ->( &block ) do
      fail ArgumentError, 'Missing block.' if !block
      @callbacks[type] << block
      self
    end
  end

  # @!method on_complete( &block )
  #   Assigns a block to be called with the response.
  #   @param [Block] block Block to be passed the response.

  # @!method on_success( &block )
  #   Assigns a block to be called with the response if the request was successful.
  #   @param [Block] block Block to be passed the response.

  # @!method on_failure( &block )
  #   Assigns a block to be called if the request fails.
  #   @param [Block] block Block to call on failure.

  # @private
  def handle_response( response )
    type = (response.code.to_i == 0) ? :on_failure : :on_success

    @callbacks[type].each { |block| block.call response }
    @callbacks[:on_complete].each { |block| block.call response }
  end

end

end
end
