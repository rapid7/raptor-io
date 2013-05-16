module Raptor
module Protocol::HTTP

#
# HTTP Data Unit, holds shared attributes of {Request} and {Response}.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class PDU

  # @return [String]  HTTP version.
  attr_reader :http_version

  # @return [Headers<String, String>]  HTTP headers as a Hash-like object.
  attr_reader :headers

  # @return [String]  {Request}/{Response} body.
  attr_reader :body

  #
  # @note All options will be sent through the class setters whenever
  #   possible to allow for normalization.
  #
  # @param  [Hash]  options PDU options.
  # @option options [String] :url The URL of the remote resource.
  # @option options [Hash] :headers HTTP headers.
  # @option options [String] :body Body.
  #
  def initialize( options = {} )
    options.each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    @headers        = Headers.new( @headers )
    @http_version ||= '1.1'
  end

  # @return [Boolean]
  #   `true` when {#http_version} is `1.1`, `false` otherwise.
  def http_1_1?
    http_version == '1.1'
  end

  # @return [Boolean]
  #   `true` when {#http_version} is `1.0`, `false` otherwise.
  def http_1_0?
    http_version == '1.0'
  end

end

end
end
