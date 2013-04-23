module Raptor
module Protocol::HTTP

#
# HTTP Data Unit, holds shared attributes of {Request} and {Response}.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class PDU

  # @return [String]  URL of the targeted resource.
  attr_reader :url

  # @return [URI]  Parsed version of {#url}.
  attr_reader :parsed_url

  # @return [Hash<String, String>]  HTTP headers as a Hash.
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

    fail ArgumentError, "Missing ':url' option." if !@url
    @parsed_url = URI(@url)
    @headers ||= {}
  end

end

end
end
