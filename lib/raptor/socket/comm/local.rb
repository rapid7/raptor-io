# -*- coding: binary -*-
require 'timeout'
require 'socket'
require 'resolv'

# Local communication using Ruby `::Socket`s
class Raptor::Socket::Comm::Local < Raptor::Socket::Comm

  # Determine whether we support IPv6
  #
  # We attempt to discover this by creating an unbound UDP socket with
  # the AF_INET6 address family
  def support_ipv6?
    return @support_ipv6 unless @support_ipv6.nil?

    @support_ipv6 = false

    if ::Socket.const_defined?('AF_INET6')
      begin
        sock = ::Socket.new(::Socket::AF_INET6, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP)
        sock.close
        @support_ipv6 = true
      rescue
      end
    end

    @support_ipv6
  end

  # Resolves a hostname to an IP address using this comm.
  #
  # @param  [String]  hostname
  def resolve( hostname )
    ::Resolv.getaddress hostname
  end

  # Resolves an IP address to a hostname using this comm.
  #
  # @param  [String]  ip_address
  def reverse_resolve( ip_address )
    ::Resolv.getname ip_address
  end

  # Connect to `:peer_host`
  #
  # @option (see Comm#create_tcp)
  # @return [Socket::TCP]
  # @raise [Raptor::Socket::Error::ConnectTimeout]
  def create_tcp(opts)
    phost = IPAddr.parse(opts[:peer_host])

    # Passing an explicit ::Socket::IPPROTO_TCP is broken on jruby
    #  See https://github.com/jruby/jruby/issues/785
    sock = ::Socket.new(phost.family, ::Socket::SOCK_STREAM, 0)
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

    Raptor::Socket::TCP.new(sock, opts)
  end

  # Listen locally on `:local_port`
  #
  # @option (see Comm#create_tcp_server)
  def create_tcp_server(opts)
    socket = TCPServer.new(opts[:local_host], opts[:local_port])

    Raptor::Socket::TCPServer.new(socket)
  end

end
