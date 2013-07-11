require 'zlib'
require 'sinatra'
require 'sinatra/contrib'

module Sinatra::Helpers
  class Stream
    def each(&front)
      @front = front
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
  headers "Transfer-Encoding" => "chunked"
  stream do |out|
    out << "foo\n"
    sleep 1
    out << "bara\r"
    sleep 2
    out << "baraf\r\n"
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
  sleep 2
  'Blah...'
end

get '/long-sleep' do
  sleep 5
  'Blah...'
end
