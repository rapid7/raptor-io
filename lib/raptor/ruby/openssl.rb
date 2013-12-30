require 'openssl'

module OpenSSL::SSL

class SSLSocket

  # OpenSSL does its own buffering which can result in a consumed TCP buffer,
  # leading {Kernel.select} to think that the SSLSocket has no more data to
  # provide, when that's not the case.
  #
  # Effectively making {Kernel.select} block forever, even though the SSLSocket's
  # buffer has not yet been consumed by the caller.
  #
  # Thus, to make the {SSLSocket} behave similarly to `Socket`, we make use
  # of this method along with a {Kernel.select} override to immediately return
  # {SSLSocket}s which still have data to read.
  #
  # @private
  #
  # See http://bugs.ruby-lang.org/issues/8875
  # See http://jira.codehaus.org/browse/JRUBY-6874
  def empty?
    @rbuffer.empty?
  end
end

class SSLServer
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

end
