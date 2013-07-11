require 'sinatra'

get /(\d+)/ do
  num = params[:captures].first.to_i - 1

  if num == 0
    'End of the line...'
  else
    redirect "/#{num}"
  end
end
