require 'zlib'
require 'sinatra'
require 'sinatra/contrib'

module Sinatra::Helpers
  class Stream
    def each(&front)
      p @front = front
      callback do
        @front.call("0\r\n\r\n")
      end

      @scheduler.defer do
        begin
          @back.call(self)
        rescue Exception => e
          @scheduler.schedule { raise e }
        end
        close unless @keep_open
      end
    end

    def <<(data)
      @scheduler.schedule do
        size = data.to_s.bytesize
        @front.call([size.to_s(16), "\r\n", data.to_s, "\r\n"].join)
      end
      self
    end
  end
end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new( request.env )
    @auth.provided? && @auth.basic? && @auth.credentials &&
        @auth.credentials == ['admin', 'secret']
  end
end

get '/chunked' do
  headers "Transfer-Encoding" => "chunked"
  stream do |out|
    out << "foo\n"
    sleep 1
    out << "bara\r"
    sleep 2
    out << "baraf\r\n"
    end
end

get '/echo' do
  params.to_s
end

get '/basic-auth' do
  protected!
  ''
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
  sleep 2
  'Blah...'
end

get '/long-sleep' do
  sleep 5
  'Blah...'
end

get /\/redirect_(\d+)_times/ do
  num = params[:captures].first.to_i - 1

  if num == 0
    'End of the line...'
  else
    redirect "/redirect_#{num}_times"
  end
end
