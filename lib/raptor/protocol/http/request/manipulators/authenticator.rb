module Raptor
module Protocol::HTTP
class Request

module Manipulators

#
# Implements automatic HTTP authentication.
#
# @author Tasos Laskos
#
class Authenticator < Manipulator

  validate_options do |options, _|
    errors = {}
    next errors if options[:skip]

    [:username, :password].each do |option|
      errors[option] = [ "Can't be blank." ] if options[option].to_s.empty?
    end

    errors
  end

  def run
    return if skip?

    callbacks = request.callbacks.dup
    request.clear_callbacks

    request.on_complete do |response|
      auth_type = type( response )

      if response.code == 401 && supported?( auth_type )
        retry_with_auth( auth_type, response )
      else
        request.callbacks = callbacks
        request.handle_response response
      end
    end
  end

  def retry_with_auth( type, response )
    remove_client_authenticators
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

  def supported?( type )
    Request::Manipulators.exist? "authenticators/#{type}"
  end

  def remove_client_authenticators
    client.manipulators.reject!{ |k, _| k.start_with? 'authenticator' }
  end

end

end
end
end
end
