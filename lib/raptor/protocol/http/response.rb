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
  #   String representation of the response, ready for HTTP transmission.
  def to_s
    fail 'Not implemented.'
  end

end

end
end
