module Raptor
module Protocols::HTTP

#
# HTTP Response.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Response < PDU

  # @return [Request] HTTP {Request} which triggered this {Response}.
  attr_reader :request

  # @return [String]
  #   String representation of the response, ready for HTTP transmission.
  def to_s
    fail 'Not implemented.'
  end

end

end
end
