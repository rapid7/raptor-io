require 'zlib'
require 'sinatra'
require 'sinatra/contrib'

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
end
