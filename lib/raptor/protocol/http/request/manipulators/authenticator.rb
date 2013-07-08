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
    return if skip?

    callbacks = request.callbacks.dup
    request.clear_callbacks

    request.on_complete do |response|
      auth_type = type( response )

      if response.code == 401 && [:basic, :digest].include?( auth_type )
        retry_with_auth( auth_type, response )
      else
        request.callbacks = callbacks
        request.handle_response response
      end
    end
  end

  def retry_with_auth( type, response )
    client.manipulators.merge!({
      "authenticators/#{type}" => options.merge( response: response )
    })
    client.queue( request, self.class.shortname => { skip: true } )
  end

  def type( response )
    response.headers['www-authenticate'].to_s.split( ' ' ).first.to_s.downcase.to_s.to_sym
  end

  def skip?
    !!options[:skip]
  end

end

end
end
end
end
