require 'digest'

module Raptor
module Protocol::HTTP
class Request

module Manipulators

#
# Implements automatic HTTP authentication.
#
# @author Tasos Laskos
#
class Authenticator < Manipulators::Base

  def run
    return if response.code != 401
    return if ![:basic, :digest].include? type

    delegate "authenticators/#{type}"
  end

  def type
    @type ||= response.headers['www-authenticate'].split( ' ' ).first.downcase.to_sym
  end

  def response
    options[:response]
  end

end

end
end
end
end
