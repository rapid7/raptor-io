require 'cgi'

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

  # @return [String]  HTTP version.
  attr_reader :http_version

  # @return [Symbol]  HTTP method.
  attr_reader :http_method

  # @return [Hash]  Request parameters.
  attr_reader :parameters

  #
  # @note This class' options are in addition to {PDU#initialize}.
  #
  # @param  [Hash]  options Request options.
  # @option options [String] :http_version ('1.1') HTTP version to use.
  # @option options [Symbol, String] :http_method (:get) HTTP method to use.
  # @option options [Hash] :parameters ({})
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

    @http_version ||= '1.1'
    @parameters   ||= {}
    @http_method  ||= :get
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
      h.merge( CGI.unescape(k) => CGI.unescape(v) )
    end
    return qparams if http_method != :get

    qparams.merge( parameters )
  end

  # @return [URI] Location of the resource to request.
  def effective_url
    cparsed_url = parsed_url.dup
    cparsed_url.query = query_parameters.map do |k, v|
      "#{CGI.escape(k)}=#{CGI.escape(v)}"
    end.join('&') if query_parameters.any?

    cparsed_url.normalize
  end

  # @return [String]  Response body to use.
  def effective_body
    return CGI.escape(body.to_s) if http_method != :post

    body_params = if !body.to_s.empty?
                    body.split('&').inject({}) do |h, pair|
                      k, v = pair.split('=', 2)
                      h.merge( CGI.unescape(k) => CGI.unescape(v) )
                    end
                  else
                    {}
                  end

    return '' if body_params.empty? && parameters.empty?

    body_params.merge( parameters ).map do |k, v|
      "#{CGI.escape(k)}=#{CGI.escape(v)}"
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

  # @return [String]
  #   String representation of the request, ready for HTTP transmission.
  def to_s
    req_url       = effective_url
    req_resource  = "#{req_url.path}"
    req_resource << "?#{req_url.query}" if req_url.query

    body = effective_body

    computed_headers = { 'Host' => req_url.host }
    computed_headers['Content-Length'] = body.size.to_s if !body.to_s.empty?

    request = "#{http_method.to_s.upcase} #{req_resource} HTTP/#{http_version}\r\n"
    computed_headers.merge(headers).each do |k, v|
      request << "#{CGI.escape(k)}: #{CGI.escape(v)}\r\n"
    end
    request << "\r\n"

    return request if body.to_s.empty?

    request << "#{body}\r\n\r\n"
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
