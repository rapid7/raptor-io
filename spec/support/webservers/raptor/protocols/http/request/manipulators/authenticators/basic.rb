require 'sinatra'

use Rack::Auth::Basic, "Protected Area" do |username, password|
  username == 'admin' && password == 'secret'
end

get '/' do
 'Restricted'
end
