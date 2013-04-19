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

end

end
end
