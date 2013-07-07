require 'optparse'
require 'sinatra/base'

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

options = {
    address: '0.0.0.0',
    port:    4567
}

OptionParser.new do |opts|

  opts.on( '-o', '--addr [host]', "set the host (default is #{options[:address]})" ) do |address|
    options[:address] = address
  end

  opts.on( '-p', '--port [port]', Integer, "set the port (default is #{options[:port]})" ) do |port|
    options[:port] = port
  end

end.parse!

Rack::Handler::Thin.run( Protected.new, Port: options[:port], Address: options[:address] )
