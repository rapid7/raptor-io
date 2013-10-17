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

  private

  # @note Set by one of the authenticators, not `self`.
  # @return [Bool]  `true` if authentication failed, `false` otherwise.
  def failed?
    !!datastore[:failed]
  end

  # Retries the request with authentication.
  #
  # @param  [Symbol]  type  Authenticator to use.
  # @param  [Raptor::Protocol::HTTP::Response]  response
  #   Response signaling the need to authenticate.
  def retry_with_auth( type, response )
    datastore[:tries] += 1

    remove_client_authenticators if ![:ntlm, :negotiate].include?( type )
    client.manipulators.merge!({
      "authenticators/#{type}" => options.merge( response: response )
    })
    requeue
  end

  # Requeues the request after the proper authenticator has been enabled.
  def requeue
    client.queue( request, shortname => { skip: true } )
  end

  # @param  [Raptor::Protocol::HTTP::Response]  response
  #   Response signaling the need to authenticate.
  # @return [Symbol]  Authentication type.
  def type( response )
    response.headers['www-authenticate'].to_s.split( ' ' ).first.to_s.downcase.to_s.to_sym
  end

  def skip?
    failed? || !!options[:skip]
  end

  # @param  [Symbol]  type  Authentication type to check.
  # @return [Bool]
  #   `true` if the authentication `type` is supported, `false` otherwise.
  def supported?( type )
    Request::Manipulators.exist? "authenticators/#{type}"
  end

  # Removes all enabled authenticators.
  def remove_client_authenticators
    client.manipulators.reject!{ |k, _| k.start_with? 'authenticator' }
  end

end

end
end
end
end
