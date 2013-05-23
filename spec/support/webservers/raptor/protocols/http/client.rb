require 'zlib'
require 'sinatra'
require 'sinatra/contrib'

get '/echo' do
  params.to_s
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
end

get /\/redirect_(\d+)_times/ do
  num = params[:captures].first.to_i - 1

  if num == 0
    'End of the line...'
  else
    redirect "/redirect_#{num}_times"
  end
end
