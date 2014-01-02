require 'sinatra/base'
require_relative '../../../../../../../../support/lib/webserver_option_parser'

class Protected < Sinatra::Base

  get '/' do
    'Restricted'
  end

  def self.new( * )
    app = Rack::Auth::Digest::MD5.new( super ) do |username|
      { 'admin' => 'secret' }[username]
    end

    app.realm  = 'Protected Area'
    app.opaque = 'secretkey'
    app
  end
end

options = WebServerOptionParser.parse
Rack::Handler.default.run( Protected.new, Port: options[:port], Address: options[:address] )
