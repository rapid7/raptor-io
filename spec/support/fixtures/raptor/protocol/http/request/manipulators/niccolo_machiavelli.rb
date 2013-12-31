module RaptorIO
module Protocol::HTTP
class Request

#
# Test manipulator.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Manipulators::NiccoloMachiavelli < Manipulator

  def run
    [client, request, options, datastore]
  end

end

end
end
end
