module Raptor
module Protocol::HTTP
class Request

module Manipulators

#
# Implements automatic HTTP redirect following.
#
# @author Tasos Laskos
#
class RedirectFollower < Manipulator

  def run
    # This request has already been handled.
    return if request.root_redirect_id

    callbacks = request.callbacks.dup
    request.clear_callbacks

    request.on_complete do |response|
      root_redirect_id = request.root_redirect_id ?
          request.root_redirect_id : request.object_id

      if response.redirect?
        if redirections[root_redirect_id].size < max
          redirections[root_redirect_id] << response

          crequest = request.dup
          crequest.root_redirect_id = root_redirect_id

          # RFC says the Location URI must be a full absolute URL however not
          # all webapps respect that.
          crequest.url = crequest.parsed_url.merge( response.headers['Location'] ).to_s

          client.queue( crequest )
          next
        else
          response.redirections = redirections.delete( root_redirect_id )
        end
      end

      request.callbacks = callbacks
      request.handle_response response
    end
  end
  
  def redirections
    datastore[:redirections] ||= Hash.new { |h, k| h[k] = [] }
  end

  def max
    @max ||= (options[:max] || 5).to_i
  end

end

end
end
end
end
