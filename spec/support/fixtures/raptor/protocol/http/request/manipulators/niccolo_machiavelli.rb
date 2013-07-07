module Raptor
module Protocol::HTTP
class Request

#
# Test manipulator.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Manipulators::NiccoloMachiavelli < Manipulators::Base

  def run
    [client, request, options, datastore]
  end

end

end
end
end
