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
    datastore[:tries] ||= 0
    return if skip?

    callbacks = request.callbacks.dup
    request.clear_callbacks

    # We need to block until authentication is complete, that's why we requeue
    # and run.

    requeue
    request.on_complete do |response|
      auth_type = type( response )

      if !failed? && response.code == 401 && supported?( auth_type )
        retry_with_auth( auth_type, response )
      else
        request.callbacks = callbacks
        request.handle_response response
        request.clear_callbacks
      end
    end
    client.run
  end

  def failed?
    !!datastore[:failed]
  end

  def retry_with_auth( type, response )
    datastore[:tries] += 1

    remove_client_authenticators if ![:ntlm, :negotiate].include?( type )
    client.manipulators.merge!({
      "authenticators/#{type}" => options.merge( response: response )
    })
    requeue
  end

  def requeue
    client.queue( request, shortname => { skip: true } )
  end

  def type( response )
    response.headers['www-authenticate'].to_s.split( ' ' ).first.to_s.downcase.to_s.to_sym
  end

  def skip?
    failed? || !!options[:skip]
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
