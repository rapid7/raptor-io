require 'zlib'
require 'sinatra/base'
require 'sinatra/contrib'
require_relative '../../support/lib/webserver_option_parser'

class Public < Sinatra::Base
  helpers Sinatra::Cookies

  get '/' do
    "Success."
  end

  get '/100' do
    if env['HTTP_EXPECT'] == '100-continue'
      100
    else
      request.body
    end
  end

  get '/204' do
    204
  end

  get '/chunked' do
    response["Transfer-Encoding"] = "chunked"

    Enumerator.new do |y|
      ["foo\r", "barz\n", "asdf"*20].each do |chunk|
        y << "#{chunk.bytesize.to_s 16}\r\n#{chunk}\r\n"
      end
      y << "0\r\n"
    end
  end

  get '/cookies' do
    cookies.map { |k, v| k.to_s + '=' + v.to_s }.join( ';' )
  end

  get '/echo' do
    params.to_s
  end

  get '/echo_body' do
    request.body
  end

  get '/gzip' do
    headers['Content-Encoding'] = 'gzip'
    io = StringIO.new

    gz = Zlib::GzipWriter.new( io )
    begin
      gz.write( 'gzip' )
    ensure
      gz.close
    end
    io.string
  end

  get '/deflate' do
    headers['Content-Encoding'] = 'deflate'

    z = Zlib::Deflate.new( Zlib::BEST_COMPRESSION )
    begin
      z.deflate( 'deflate', Zlib::FINISH )
    ensure
      z.close
    end
  end

  get '/sleep' do
    sleep 1
    'Blah...'
  end

  get '/long-sleep' do
    sleep 5
    'Blah...'
  end

end

class ProtectedBasic < Sinatra::Base
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    username == 'admin' && password == 'secret'
  end

  get '/' do
    'Restricted'
  end
end

class ProtectedDigest < Sinatra::Base
  get '/' do
    'Restricted'
  end

  def self.new( * )
    app = Rack::Auth::Digest::MD5.new( super ) do |username|
      { 'admin' => 'secret' }[username]
    end

    app.realm  = 'Basic Protected Area'
    app.opaque = 'secretkey'
    app
  end
end

class Protected < Sinatra::Base
  get '/' do
    'Restricted'
  end

  def self.new( * )
    app = Rack::Auth::Digest::MD5.new( super ) do |username|
      { 'admin' => 'secret' }[username]
    end

    app.realm  = 'Digest Protected Area'
    app.opaque = 'secretkey'
    app
  end
end


if __FILE__ == $0
  options = WebServerOptionParser.parse
  map = Rack::URLMap.new({
    "/" => Public,
    "/basic/" => ProtectedBasic,
    "/digest/" => ProtectedDigest,
  })
  Rack::Handler.default.run(map, Port: options[:port], Address: options[:address])
end

