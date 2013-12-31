require 'net/ntlm'

module Raptor
module Protocol::HTTP
class Request

module Manipulators
module Authenticators

#
# Implements HTTP Negotiate authentication.
#
# @author Tasos Laskos
#
class Negotiate < Manipulator

  def run
    return if skip?
    client.manipulators.delete shortname

    t2 = authorize( type1 ).headers['www-authenticate'].split( ' ' ).last

    if authorize( type3( t2 ) ).code == 401 && client.manipulators['authenticator']
      client.datastore['authenticator'][:failed] = true
    end
  end

  private

  def provider
    'Negotiate'
  end

  def authorize( message )
    client.get( request.url,
                mode: :sync,
                manipulators: {
                    'authenticator' => { skip: true },
                    shortname       => { skip: true },
                },
                headers: { 'Authorization' => "#{provider} #{message}" } )
  end

  def skip?
    !!options[:skip]
  end

  def type1
    Net::NTLM::Message::Type1.new.encode64
  end

  def type3( type2 )
    Net::NTLM::Message.decode64( type2 ).response(
        {
            user:     options[:username],
            password: options[:password],
            domain:   options[:domain]
        },
        { ntlmv2: true }
    ).encode64
  end

end

end
end
end
end
end
