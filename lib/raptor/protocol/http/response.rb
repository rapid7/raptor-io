require 'zlib'
require 'stringio'

module Raptor
module Protocol::HTTP

#
# HTTP Response.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Response < Message

  # @return [Integer] HTTP response status code.
  attr_reader :code

  # @return [String] HTTP response status message.
  attr_reader :message

  # @return [Request] HTTP {Request} which triggered this {Response}.
  attr_accessor :request

  # @return [Array<Response>]
  #   Automatically followed redirections that eventually led to this response.
  attr_accessor :redirections

  # @return [Exception] Exception representing the error that occurred.
  attr_reader :error

  #
  # @note This class' options are in addition to {Message#initialize}.
  #
  # @param  [Hash]  options Request options.
  # @option options [Integer] :code HTTP response status code.
  # @option options [Request] :request HTTP request that triggered this response.
  #
  # @see Message#initialize
  #
  def initialize( options = {} )
    super( options )

    @body = @body.force_utf8 if text?
    @code ||= 0

    # Holds the redirection responses that eventually led to this one.
    @redirections ||= []
  end

  # @return [Boolean]
  #   `true` if the response is a `3xx` redirect **and** there is a `Location`
  #   header field.
  def redirect?
    code >= 300 && code <= 399 && !!headers['Location']
  end

  # @note Depends on the response code.
  #
  # @return [Boolean]
  #   `true` if the remote resource has been modified since the date given in
  #   the `If-Modified-Since` request header field, `false` otherwise.
  def modified?
    code != 304
  end

  # @return [Bool]
  #   `true` if the response body is textual in nature, `false` otherwise
  #   (if binary).
  def text?
    return if !@body

    if (type = headers['content-type'])
      return true if type.start_with?( 'text/' )

      # Non "application/" content types will surely not be text-based
      # so bail out early.
      return false if !type.start_with?( 'application/' )
    end

    # Last resort, more resource intensive binary detection.
    !@body.binary?
  end

  # @return [String]
  #   String representation of the response.
  def to_s
    r = "HTTP/#{version} #{code}"
    r <<  " #{message}" if message
    r <<  "\r\n"
    r << "#{headers.to_s}\r\n\r\n"
    r << body.to_s
  end

  # @param  [String]  response  HTTP response.
  # @return [Response]
  def self.parse( response )
    options ||= {}

    headers_string, options[:body] = response.split( HEADER_SEPARATOR_PATTERN, 2 )
    request_line   = headers_string.to_s.lines.first.to_s.chomp

    options[:version], options[:code], options[:message] =
        request_line.scan( /HTTP\/([\d.]+)\s+(\d+)\s*(.*)\s*$/ ).flatten

    options.delete(:message) if options[:message].to_s.empty?

    options[:code] = options[:code].to_i

    if !headers_string.to_s.empty?
      options[:headers] =
          Headers.parse( headers_string.split( CRLF_PATTERN )[1..-1].join( "\r\n" ) )
    else
      options[:headers] = Headers.new
    end

    if !options[:body].to_s.empty?

      # If any encoding has been applied to the body, remove all evidence of it
      # and adjust the content-length accordingly.

      case options[:headers]['content-encoding'].to_s.downcase
        when 'gzip', 'x-gzip'
          options[:body] = unzip( options[:body] )
        when 'deflate', 'compress', 'x-compress'
          options[:body] = inflate( options[:body] )
      end

      if options[:headers].delete( 'content-encoding' ) ||
          options[:headers].delete( 'transfer-encoding' )
        options[:headers]['content-length'] = options[:body].size
      end
    end

    new( options )
  end

  # @param  [String]  str Inflates `str`.
  # @return [String]  Inflated `str`.
  def self.inflate( str )
    z = Zlib::Inflate.new
    s = z.inflate( str )
    z.close
    s
  end

  # @param  [String]  str Unzips `str`.
  # @return [String]  Unziped `str`.
  def self.unzip( str )
    s = ''
    s.force_encoding( 'ASCII-8BIT' ) if s.respond_to?( :encoding )
    gz = Zlib::GzipReader.new( StringIO.new( str, 'rb' ) )
    s << gz.read
    gz.close
    s
  end

end

end
end
