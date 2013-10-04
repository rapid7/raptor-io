require 'openssl'

class OpenSSL::SSL::SSLServer

  # Stolen from: OpenSSL::SSL::SSLServer
  def accept_nonblock
    sock = @svr.accept_nonblock

    begin
      ssl = OpenSSL::SSL::SSLSocket.new(sock, @ctx)
      ssl.sync_close = true
      ssl.accept if @start_immediately
      ssl
    rescue SSLError => ex
      sock.close
      raise ex
    end
  end

end
