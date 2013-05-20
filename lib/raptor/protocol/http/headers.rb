require 'uri'

module Raptor
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
  def []( field )
    fetch( format_field_name(field.to_s.downcase) )
  end

  # @note `field` will be capitalized appropriately before storing.
  # @param  [String]  field Field name
  # @param  [String]  value Field value.
  # @return [String]  Field `value`.
  def []=( field, value )
    store( format_field_name(field.to_s.downcase), value.to_s )
  end

  # @return [String]  HTTP headers formatted for transmission.
  def to_s
    map { |k, v| "#{k}: #{v}" }.join( "\r\n" )
  end

  # @param  [String]  headers_string
  # @return [Headers]
  def self.parse( headers_string )
    headers = Headers.new
    return headers if headers_string.to_s.empty?

    headers_string.split( /[\r\n]+/ ).each do |header|
      k, v = header.split( ':', 2 )
      headers[k.to_s.strip] = v.to_s.strip
    end
    headers
  end

  private

  def format_field_name( field )
    field.to_s.split( '-' ).map( &:capitalize ).join( '-' )
  end

end

end
end
