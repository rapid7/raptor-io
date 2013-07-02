module Raptor
module Protocol::HTTP
class Request

#
# Test manipulator.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Manipulators::Fooer < Manipulators::Base

  def run
    request.url += ('foo' * options[:times])
  end

end

end
end
end
