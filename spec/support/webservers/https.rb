require_relative '../lib/webserver_option_parser'
require 'sinatra/base'
require 'webrick'
require 'webrick/https'
require 'openssl'

options = WebServerOptionParser.parse

name = "/C=US/ST=SomeState/L=SomeCity/O=Organization/OU=Unit/CN=localhost"
ca  = OpenSSL::X509::Name.parse( name )
key = OpenSSL::PKey::RSA.new( 1024 )
crt = OpenSSL::X509::Certificate.new

crt.version = 2
crt.serial  = 1
crt.subject = ca
crt.issuer  = ca
crt.public_key = key.public_key
crt.not_before = Time.now
crt.not_after  = Time.now + 1 * 365 * 24 * 60 * 60 # 1 year

options = {
    Address:         options[:address],
    Port:            options[:port],
    SSLEnable:       true,
    SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
    SSLCertificate:  crt,
    SSLPrivateKey:   key,
    SSLCertName:     [["CN", WEBrick::Utils::getservername]],
}

class HTTPSServer < Sinatra::Base

    get '/' do
        'Stuff...'
    end

end

# Use WEBrick explicitly here because Thin doesn't seem to do SSL
# correctly.  It's probably just the way we're configuring it but
# whatever, I don't care, WEBrick works.
server = ::Rack::Handler::WEBrick
trap( :INT ) { server.shutdown }

server.run( HTTPSServer, options )
