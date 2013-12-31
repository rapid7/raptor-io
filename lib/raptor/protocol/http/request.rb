module Raptor
module Protocol::HTTP

#
# HTTP Request.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Request < Message

  #
  # {HTTP::Request} error namespace.
  #
  # All {HTTP::Request} errors inherit from and live under it.
  #
  # @author Tasos "Zapotek" Laskos
  #
  class Error < Protocol::HTTP::Error
  end

  require_relative 'request/manipulators'

  # Acceptable response callback types.
  CALLBACK_TYPES = [:on_complete, :on_failure, :on_success]

  # @return [Symbol]  HTTP method.
  attr_reader :http_method

  # @return [String]  URL of the targeted resource.
  attr_reader :url

  # @return [URI]  Parsed version of {#url}.
  attr_reader :parsed_url

  # @return [Hash]  Request parameters.
  attr_reader :parameters

  # @return [Integer, Float] Timeout in seconds.
  attr_accessor :timeout

  # @note Defaults to `true`.
  # @return [Bool]
  #   Whether or not to automatically continue on responses with status 100.
  attr_reader :continue

  # @note Defaults to `false`.
  # @return [Bool]
  #   Whether or not encode any of the given data for HTTP transmission.
  attr_accessor :raw

  attr_accessor :callbacks

  # @private
  attr_accessor :root_redirect_id

  # @return [String]  IP address -- populated by {Server}.
  attr_accessor :client_address

  #
  # @note This class' options are in addition to {Message#initialize}.
  #
  # @param  [Hash]  options Request options.
  # @option options [String] :version ('1.1') HTTP version to use.
  # @option options [Symbol, String] :http_method (:get) HTTP method to use.
  # @option options [Hash] :parameters ({})
  #   Parameters to send. If performing a GET request and the URL has parameters
  #   of its own they will be merged and overwritten.
  # @option options [Integer]  :timeout
  #   Max time to wait for a response in seconds.
  # @option options [Bool]  :continue
  #   Whether or not to automatically continue on responses with status 100.
  #   Only applicable when the 'Expect' header has been set to '100-continue'.
  # @option options [Bool]  :raw (false)
  #   `true` to not encode any of the given data for HTTP transmission, `false`
  #   otherwise.
  #
  # @see Message#initialize
  # @see #parameters=
  # @see #http_method=
  #
  def initialize( options = {} )
    super( options )

    clear_callbacks

    fail ArgumentError, "Missing ':url' option." if !@url

    @parameters  ||= {}
    @http_method ||= :get
    @continue    = true  if @continue.nil?
    @raw         = false if @raw.nil?
  end

  # Clears all callbacks.
  def clear_callbacks
    @callbacks = CALLBACK_TYPES.inject( {} ) { |h, type| h[type] = []; h }
    nil
  end

  # @return [Bool]
  #   Whether or not encode any of the given data for HTTP transmission.
  def raw?
    !!@raw
  end

  # @return [Bool]
  #   Whether or not to automatically continue on responses with status 100.
  def continue?
    !!@continue
  end

  # @param  [String]  uri Request URL.
  # @return  [String]  `uri`
  def url=( uri )
    @url = uri
    @parsed_url= URI(@url)
    @url
  end

  # @return [Integer] Identification for the remote host:port.
  def connection_id
    "#{parsed_url.host}:#{parsed_url.port}".hash
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

    qparams = query.split('&').inject({}) do |h, pair|
      k, v = pair.split('=', 2)
      h.merge( decode_if_not_raw(k) => decode_if_not_raw(v) )
    end
    return qparams if http_method != :get

    qparams.merge( parameters )
  end

  # @return [URI] Location of the resource to request.
  def effective_url
    cparsed_url = parsed_url.dup
    cparsed_url.query = query_parameters.map do |k, v|
      "#{encode_if_not_raw(k)}=#{encode_if_not_raw(v)}"
    end.join('&') if query_parameters.any?

    cparsed_url.normalize
  end

  # @return [String]  Response body to use.
  def effective_body
    return '' if headers['Expect'] == '100-continue'
    return encode_if_not_raw(body.to_s)

    body_params = if !body.to_s.empty?
                    body.split('&').inject({}) do |h, pair|
                      k, v = pair.split('=', 2)
                      h.merge( decode_if_not_raw(k) => decode_if_not_raw(v) )
                    end
                  else
                    {}
                  end

    return '' if body_params.empty? && parameters.empty?

    body_params.merge( parameters ).map do |k, v|
      "#{encode_if_not_raw(k)}=#{encode_if_not_raw(v)}"
    end.join('&')
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

  # @return [Bool] `true` if the request if idempotent, `false` otherwise.
  def idempotent?
    http_method != :post
  end

  # @return [String]  Server-side resource to request.
  def resource
    req_resource  = "#{effective_url.path}"
    req_resource << "?#{effective_url.query}" if effective_url.query
    req_resource
  end

  # @return [String]
  #   String representation of the request, ready for HTTP transmission.
  def to_s
    final_body = effective_body

    computed_headers = Headers.new( 'Host' => "#{effective_url.host}:#{effective_url.port}" )
    computed_headers['Content-Length'] = final_body.size.to_s if !final_body.to_s.empty?

    request = "#{http_method.to_s.upcase} #{resource} HTTP/#{version}#{CRLF}"
    request << computed_headers.merge(headers).to_s
    request << HEADER_SEPARATOR

    return request if final_body.to_s.empty?

    request << final_body.to_s
  end

  CALLBACK_TYPES.each do |type|
    define_method type, ->( &block ) do
      return @callbacks[type] if !block
      @callbacks[type] << block
      self
    end

    define_method "#{type}=" do |callbacks|
      @callbacks[type] = [callbacks].flatten.compact
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

  #
  # Handles the `response` to `self` by passing to the appropriate callbacks.
  #
  # @param  [Response]  response
  #
  # @private
  def handle_response( response )
    response.request = self

    type = (response.code.to_i == 0) ? :on_failure : :on_success

    @callbacks[type].each { |block| block.call response }
    @callbacks[:on_complete].each { |block| block.call response }
    true
  end

  # @return [Request] Duplicate of `self`.
  def dup
    r = self.class.new( url: url )
    instance_variables.each do |iv|
      r.instance_variable_set iv, instance_variable_get( iv )
    end
    r
  end

  # @param  [String]  request HTTP request message to parse.
  # @return [Request]
  def self.parse( request )
    data = {}
    first_line, headers_and_body = request.split( CRLF_PATTERN, 2 )
    data[:http_method], data[:url], data[:version] = first_line.scan( /([A-Z]+)\s+(.*)\s+HTTP\/([0-9\.]+)/ ).flatten
    headers, data[:body] = headers_and_body.split( HEADER_SEPARATOR_PATTERN, 2 )

    # Use Host to fill in the parsed_uri stuff.
    data[:headers] = Headers.parse( headers.to_s )

    new data
  end

  private

  def encode_if_not_raw( str )
    raw? ? str : CGI.escape( str )
  end

  def decode_if_not_raw( str )
    raw? ? str : CGI.unescape( str )
  end

end

end
end
