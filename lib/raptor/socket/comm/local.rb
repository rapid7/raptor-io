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
        sock = ::Socket.new(::Socket::AF_INET6, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP)
        sock.close
        @support_ipv6 = true
      rescue
      end
    end

    return @support_ipv6
  end

  # Connect to `:peer_host`
  #
  # @option (see Comm#create_tcp)
  # @return [Socket::Tcp]
  # @raise [Raptor::Socket::Error::ConnectTimeout]
  def create_tcp(opts)
    phost = IPAddr.parse(opts[:peer_host])

    sock = ::Socket.new(phost.family, ::Socket::SOCK_STREAM, ::Socket::IPPROTO_TCP)
    sock.do_not_reverse_lookup = true

    if opts[:local_port] || opts[:local_host]
      sock.bind(::Socket.pack_sockaddr_in(opts[:local_port], opts[:local_host]))
    end

    begin
      sock.connect_nonblock(::Socket.pack_sockaddr_in(opts[:peer_port], phost.to_s))
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      raise Raptor::Socket::Error::ConnectionRefused
    rescue Errno::EINPROGRESS
      # This should almost always be raised with a call to
      # connect_nonblock. When the socket finishes connecting it
      # becomes available for writing.
      res = select(nil, [sock], nil, opts[:connect_timeout] || 2)
      if res.nil?
        raise Raptor::Socket::Error::ConnectionTimeout
      end
    end

    Raptor::Socket::Tcp.new(sock)
  end

  # Listen locally on `:local_port`
  #
  # @option (see Comm#create_tcp_server)
  def create_tcp_server(opts)
    socket = TCPServer.new(opts[:local_host], opts[:local_port])

    Raptor::Socket::TcpServer.new(socket)
  end

end
