module RaptorIO
module Protocol::HTTP

#
# HTTP message, holds shared attributes of {Request} and {Response}.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Message

  # @return [String]  HTTP version.
  attr_reader :version

  # @return [Headers<String, String>]  HTTP headers as a Hash-like object.
  attr_reader :headers

  # @return [String]  {Request}/{Response} body.
  attr_accessor :body

  #
  # @note All options will be sent through the class setters whenever
  #   possible to allow for normalization.
  #
  # @param  [Hash]  options Message options.
  # @option options [String] :url The URL of the remote resource.
  # @option options [Hash] :headers HTTP headers.
  # @option options [String] :body Body.
  # @option options [String] :version (1.1) HTTP version.
  #
  def initialize( options = {} )
    options.each do |k, v|
      begin
        send( "#{k}=", v )
      rescue NoMethodError
        instance_variable_set( "@#{k}".to_sym, v )
      end
    end

    @headers  = Headers.new( @headers )
    @version ||= '1.1'
  end

  # @return [Bool]
  #   `true` if the connections should be reused, `false` otherwise.
  def keep_alive?
    connection = headers['Connection'].to_s.downcase

    return connection == 'keep-alive' if version.to_f < 1.1
    connection != 'close'
  end

  # @return [Boolean]
  #   `true` when {#version} is `1.1`, `false` otherwise.
  def http_1_1?
    version == '1.1'
  end

  # @return [Boolean]
  #   `true` when {#version} is `1.0`, `false` otherwise.
  def http_1_0?
    version == '1.0'
  end

end

end
end
