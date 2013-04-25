module Raptor
module Protocol::HTTP

#
# HTTP Response.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Response < PDU

  # @return [Integer] HTTP response status code.
  attr_reader :code

  # @return [String] HTTP response status message.
  attr_reader :message

  # @return [Request] HTTP {Request} which triggered this {Response}.
  attr_reader :request

  #
  # @note This class' options are in addition to {PDU#initialize}.
  #
  # @param  [Hash]  options Request options.
  # @option options [Integer] :code HTTP response status code.
  # @option options [Request] :request HTTP request that triggered this response.
  #
  # @see PDU#initialize
  #
  def initialize( options = {} )
    super( options )

    @code ||= 0
  end

  # @return [String]
  #   String representation of the response.
  def to_s
    @original || ''
  end

  #
  # @param  [String]  response  HTTP response.
  #
  # @return [Response]
  #
  def self.parse( response )
    options          ||= {}
    options[:original] = response

    headers_string, options[:body] = response.split( "\r\n\r\n", 2 )
    request_line  = headers_string.lines.first

    options[:http_version], options[:code], options[:message] =
        request_line.scan( /HTTP\/([\d.]+)\s+(\d+)\s+(.*)$/ ).flatten

    options[:code] = options[:code].to_i

    headers = {}
    headers_string.split( /[\r\n]+/ )[1..-1].each do |header|
      k, v = header.split( ':', 2 )
      k = CGI.unescape( k.to_s.strip )
      v = CGI.unescape( v.to_s.strip )
      headers[k] = v
    end

    options[:headers] = headers

    new( options )
  end

  protected

  def original=( response )
    @original = response
  end

end

end
end
