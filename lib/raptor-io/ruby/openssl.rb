require 'openssl'

class OpenSSL::SSL::SSLServer
  # Guard this in case stdlib ever implements it
  unless method_defined?(:accept_nonblock)
    # Non-blocking version of accept, stolen directly from the blocking
    # version, OpenSSL::SSL::SSLServer#accept.
    def accept_nonblock
      sock = @svr.accept_nonblock

      begin
        ssl = OpenSSL::SSL::SSLSocket.new(sock, @ctx)
        ssl.sync_close = true
        ssl.accept if @start_immediately
        ssl
      rescue OpenSSL::SSL::SSLError => ex
        sock.close
        raise ex
      end
    end
  end
end

