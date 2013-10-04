module Kernel

  # Wraps `IO.select` to compensate for some exentricities of {OpenSSL::SSL::SSLSocket}.
  # {OpenSSL::SSL::SSLSocket} whose buffer hasn't been consumed are returned immediately.
  def select( read = nil, write = nil, errors = nil, timeout = nil )
    if read.is_a? Array
      openssl_sockets = read.select { |s| s.is_a?( Raptor::Socket::TCP::SSL ) && !s.empty? }
      return [openssl_sockets, [], []] if openssl_sockets.any?
    end

    IO.select( read, write, errors, timeout )
  end
end
