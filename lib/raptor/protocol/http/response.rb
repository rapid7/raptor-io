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
    return @original if @original

    r = "HTTP/#{http_version} #{code} #{message}\r\n"
    r << "#{headers.to_s}\r\n\r\n"
    r << body
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
    request_line   = headers_string.to_s.lines.first.to_s.chomp

    options[:http_version], options[:code], options[:message] =
        request_line.scan( /HTTP\/([\d.]+)\s+(\d+)\s+(.*)$/ ).flatten

    options[:code] = options[:code].to_i

    if !headers_string.to_s.empty?
      options[:headers] =
          Headers.parse( headers_string.split( /[\r\n]+/ )[1..-1].join( "\r\n" ) )
    else
      options[:headers] = Headers.new
    end

    new( options )
  end

  protected

  def original=( response )
    @original = response
  end

end

end
end
