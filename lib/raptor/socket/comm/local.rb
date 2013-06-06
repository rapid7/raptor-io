# -*- coding: binary -*-
require 'timeout'
require 'socket'

###
#
# Local communication class factory.
#
###
class Raptor::Socket::Comm::Local

  include Raptor::Socket::Comm

  # Cache our IPv6 support flag
  @support_ipv6 = nil

  #
  # Determine whether we support IPv6
  #
  def support_ipv6?
    return @support_ipv6 if not @support_ipv6.nil?

    @support_ipv6 = false

    if (::Socket.const_defined?('AF_INET6'))
      begin
        s = ::Socket.new(::Socket::AF_INET6, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP)
        s.close
        @support_ipv6 = true
      rescue
      end
    end

    return @support_ipv6
  end

end
