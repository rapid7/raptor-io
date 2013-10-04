# -*- coding: binary -*-
require 'raptor/socket'
require 'ipaddr'
require 'raptor/ruby/ipaddr'

###
#
# Provides the basic interface that a derived class must implement
# in order to be a routable socket creator.
#
# See {Raptor::Socket::Comm::Local} for an implementation using sockets
# created with standard Ruby Socket classes.
#
# Subclasses must implement the following methods:
#
#   * `resolve`
#   * `create_tcp`
#   * `create_tcp_server`
#   * `create_udp`
#   * `create_udp_server`
#   * `support_ipv6?`
#
###
class Raptor::Socket::Comm
  require 'raptor/socket/comm/local'

  # Creates a socket on this Comm based on the supplied uniform
  # parameters.
  #
  # @option opts :switch_board [SwitchBoard]
  # @option opts :port [Fixnum] Optional based on proto
  # @return [Raptor::Socket]
  def create(opts)
    opts = opts.dup
    opts[:peer_host] = IPAddr.parse(opts[:peer_host])

    sock = case opts.delete(:proto)
           when :tcp then opts[:server] ? create_tcp_server(opts) : create_tcp(opts)
           when :udp then opts[:server] ? create_udp_server(opts) : create_udp(opts)
           end

    sock
  end

  # Resolves a hostname to an IP address using this comm.
  #
  # @abstract
  #
  # @param  [String]  hostname
  def resolve( hostname )
    raise NotImplementedError
  end

  # Resolves an IP address to a hostname using this comm.
  #
  # @abstract
  #
  # @param  [String]  ip_address
  def reverse_resolve( ip_address )
    raise NotImplementedError
  end

  # Connect to a host over TCP.
  #
  # @abstract
  #
  # @option opts :peer_host [String,IPAddr]
  # @option opts :peer_port [Fixnum]
  # @option opts :local_host [String,IPAddr]
  # @option opts :local_port [Fixnum]
  def create_tcp(opts)
    raise NotImplementedError
  end

  # Create a UDP socket bound to the given :peer_host
  #
  # @abstract
  #
  # @option opts :peer_host [String,IPAddr]
  # @option opts :peer_port [Fixnum]
  # @option opts :local_host [String,IPAddr]
  # @option opts :local_port [Fixnum]
  def create_udp(opts)
    raise NotImplementedError
  end

  # Create a TCP server listening on :local_port
  #
  # @abstract
  #
  # @option opts :local_host [String,IPAddr]
  # @option opts :local_port [Fixnum]
  # @option opts :ssl_context [OpenSSL::SSL::Context]
  def create_tcp_server(opts)
    raise NotImplementedError
  end

  # Create a UDP server listening on :local_port
  #
  # @abstract
  #
  # @option opts :local_host [String,IPAddr]
  # @option opts :local_port [Fixnum]
  def create_udp_server(opts)
    raise NotImplementedError
  end


end

