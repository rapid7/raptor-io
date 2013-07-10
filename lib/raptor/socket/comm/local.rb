# -*- coding: binary -*-
require 'timeout'
require 'socket'

# Local communication using Ruby `::Socket`s
class Raptor::Socket::Comm::Local < Raptor::Socket::Comm

  # Cache our IPv6 support flag
  @support_ipv6 = nil

  #
  # Determine whether we support IPv6
  #
  # We attempt to discover this by creating an unbound UDP socket with
  # the AF_INET6 address family
  def support_ipv6?
    return @support_ipv6 if instance_variable_defined?(:@support_ipv6)

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

  # Connect to `:peer_host`
  #
  # @option (see Comm#create_tcp)
  def create_tcp(opts)
    socket = TCPSocket.new(opts[:peer_host], opts[:peer_port], opts[:local_host], opts[:local_port])

    Raptor::Socket::Tcp.new(socket)
  end

  # Listen locally on `:local_port`
  #
  # @option (see Comm#create_tcp_server)
  def create_tcp_server(opts)
    socket = TCPServer.new(opts[:local_host], opts[:local_port])

    Raptor::Socket::TcpServer.new(socket)
  end

end
