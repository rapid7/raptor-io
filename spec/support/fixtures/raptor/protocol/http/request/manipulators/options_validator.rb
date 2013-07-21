module Raptor
module Protocol::HTTP
class Request

#
# Test manipulator.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Manipulators::OptionsValidator < Manipulator

  validate_options do |options, client, request|
    errors = {}
    next errors if options[:mandatory_string].is_a? String

    errors[:mandatory_string] = 'Must be string.'
    errors
  end

  def run
    options[:mandatory_string] * 10
  end

end

end
end
end
