require 'digest'

module RaptorIO
module Protocol::HTTP
class Request

module Manipulators
module Authenticators

#
# Implements HTTP Digest authentication as per RFC2069.
#
# @see http://tools.ietf.org/html/rfc2069
# @see http://en.wikipedia.org/wiki/Digest_access_authentication
#
# @author Tasos Laskos
#
class Digest < Manipulator

  def run
    authorization = {
        'Digest username' => username,
        realm:               challenge[:realm],
        nonce:               challenge[:nonce],
        uri:                 request.resource,
        qop:                 challenge[:qop],
        nc:                  nc,
        cnonce:              cnonce,
        response:            response,
        algorithm:           algorithm_name,
        opaque:              challenge[:opaque]
    }
    request.headers['Authorization'] = authorization.map { |k, v| "#{k}=\"#{v}\"" }.join( ', ' )
  end

  private

  def algorithm_klass
    if challenge[:algorithm].to_s =~ /(.+)(-sess)?$/
      case $1
        when 'MD5' then ::Digest::MD5
        when 'SHA1' then ::Digest::SHA1
        when 'SHA2' then ::Digest::SHA2
        when 'SHA256' then ::Digest::SHA256
        when 'SHA384' then ::Digest::SHA384
        when 'SHA512' then ::Digest::SHA512
        when 'RMD160' then ::Digest::RMD160
        else raise Error, "Unknown algorithm \"#{$1}\"."
      end
    else
      ::Digest::MD5
    end
  end

  def algorithm_name
    algorithm_klass.to_s.split( '::' ).last
  end

  def sess?
    challenge[:algorithm].to_s.include? '-sess'
  end

  def H( data )
    algorithm_klass.hexdigest( data )
  end

  def A1
    without_sess = [ username, challenge[:realm], password ] * ':'

    if sess?
      H( [without_sess, challenge[:nonce], cnonce ] * ':' )
    else
      without_sess
    end
  end

  def A2
    [ request.http_method.to_s.upcase, request.resource ] * ':'
  end

  def H1
    H( A1() )
  end

  def H2
    H( A2() )
  end

  def response
    if ['auth', 'auth-int'].include? challenge[:qop]
      return H( [H1(), challenge[:nonce], nc, cnonce, challenge[:qop],  H2()] * ':' )
    end

    H( [H1(), challenge[:nonce], H2()] * ':' )
  end

  def cnonce
    [Time.now.to_i.to_s].pack( 'm*' ).strip
  end

  def nc
    @nc ||= self.class.nc
  end
  def self.nc
    @nc ||= 0
    @nc += 1
  end

  def challenge
    return @challenge if @challenge

    challenge_options = {}

    options[:response].headers['www-authenticate'].split( ',' ).each do |pair|
      matches = pair.strip.match( /(.+)="(.*)"/ )
      challenge_options[matches[1].to_sym] = matches[2]
    end
    challenge_options[:realm] = challenge_options.delete( :'Digest realm' )

    @challenge = challenge_options
  end

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
