module RaptorIO
module Protocol::HTTP
class Request

module Manipulators
module Authenticators

#
# Implements HTTP Basic authentication.
#
# @author Tasos Laskos
#
class Basic < Manipulator

  def run
    request.headers['Authorization'] =
        "Basic #{Base64.encode64("#{username}:#{password}").chomp}"
  end

  private

  def username
    options[:username]
  end

  def password
    options[:password]
  end

end

end
end
end
end
end
