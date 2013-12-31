require 'webrick'
require 'uri'

module RaptorIO
module Protocol::HTTP

#
# HTTP Headers, holds shared attributes of {Request} and {Response}.
#
# For convenience, Hash-like getters and setters provide case-insensitive access.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Headers < Hash

  # @param  [Headers, Hash] headers
  def initialize( headers = {} )
    (headers || {}).each do |k, v|
      self[k] = v
    end
  end

  # @note `field` will be capitalized appropriately before storing.
  # @param  [String]  field Field name
  # @return [String]  Field value.
  def delete( field )
    super format_field_name( field.to_s.downcase )
  end

  # @note `field` will be capitalized appropriately before storing.
  # @param  [String]  field Field name
  # @return [String]  Field value.
  def include?( field )
    super format_field_name( field.to_s.downcase )
  end

  # @note `field` will be capitalized appropriately before storing.
  # @param  [String]  field Field name
  # @return [String]  Field value.
  def []( field )
    super format_field_name( field.to_s.downcase )
  end

  # @note `field` will be capitalized appropriately before storing.
  # @param  [String]  field Field name
  # @param  [Array<String>, String]  value Field value.
  # @return [String]  Field `value`.
  def []=( field, value )
    super format_field_name( field.to_s.downcase ),
          value.is_a?( Array ) ? value : value.to_s
  end

  # @return [Array<String>]   Set-cookie strings.
  def set_cookie
    return [] if self['set-cookie'].to_s.empty?
    [self['set-cookie']].flatten
  end

  # @return [Array<Hash>]   Cookies as hashes.
  def parsed_set_cookie
    return [] if set_cookie.empty?

    set_cookie.map { |set_cookie_string|
      WEBrick::Cookie.parse_set_cookies( set_cookie_string ).flatten.uniq.map do |cookie|
        cookie_hash = {}
        cookie.instance_variables.each do |var|
          cookie_hash[var.to_s.gsub( /@/, '' ).to_sym] = cookie.instance_variable_get( var )
        end

        # Replace the string with a Time object.
        cookie_hash[:expires] = cookie.expires

        cookie_hash
      end
    }.flatten.compact
  end

  # @return [Array<Hash>] Request cookies.
  def cookies
    return [] if !self['cookie']

    WEBrick::Cookie.parse( self['cookie'] ).flatten.uniq.map do |cookie|
      cookie_hash = {}
      cookie.instance_variables.each do |var|
        cookie_hash[var.to_s.gsub( /@/, '' ).to_sym] = cookie.instance_variable_get( var )
      end

      # Replace the string with a Time object.
      cookie_hash[:expires] = cookie.expires

      cookie_hash
    end
  end

  # @return [String]  HTTP headers formatted for transmission.
  def to_s
    map { |k, v|
      if v.is_a? Array
        v.map do |cv|
          "#{k}: #{cv}"
        end
      else
        "#{k}: #{v}"
      end
    }.flatten.join( CRLF )
  end

  # @param  [String]  headers_string
  # @return [Headers]
  def self.parse( headers_string )
    return Headers.new if headers_string.to_s.empty?

    headers = Hash.new { |h, k| h[k] = [] }
    headers_string.split( CRLF_PATTERN ).each do |header|
      k, v = header.split( ':', 2 )
      headers[k.to_s.strip] << v.to_s.strip
    end

    headers.each { |k, v| headers[k] = v.first if v.size == 1 }
    new headers
  end

  private

  def format_field_name( field )
    field.to_s.split( '-' ).map( &:capitalize ).join( '-' )
  end

end

end
end
