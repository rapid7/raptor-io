# -*- coding: binary -*-
require 'raptor-io/socket'
require 'ipaddr'

###
#
# Provides the basic interface that a derived class must implement
# in order to be a routable socket creator.
#
# See {RaptorIO::Socket::Comm::Local} for an implementation using sockets
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
class RaptorIO::Socket::Comm
  require 'raptor-io/socket/comm/local'
  require 'raptor-io/socket/comm/socks'
  require 'raptor-io/socket/comm/sapni'

  # Creates a socket on this Comm based on the supplied uniform
  # parameters.
  #
  # @option options :switch_board [SwitchBoard]
  # @option options :port [Fixnum] Optional based on proto
  # @option options :protocol [Symbol]
  #   * `:tcp`
  #   * `:udp`
  #
  # @return [RaptorIO::Socket]
  def create( options )
    options = options.dup
    options[:peer_host] = IPAddr.parse(options[:peer_host])

    case options.delete(:protocol)
      when :tcp
        options[:server] ? create_tcp_server(options) : create_tcp(options)

      when :udp
        options[:server] ? create_udp_server(options) : create_udp(options)
    end
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
  # @param ip_address [String]
  def reverse_resolve( ip_address )
    raise NotImplementedError
  end

  # Connect to a host over TCP.
  #
  # @abstract
  #
  # @option options :peer_host [String,IPAddr]
  # @option options :peer_port [Fixnum]
  # @option options :local_host [String,IPAddr]
  # @option options :local_port [Fixnum]
  # @return [RaptorIO::Socket::TCP]
  def create_tcp(options)
    raise NotImplementedError
  end

  # Create a UDP socket bound to the given :peer_host
  #
  # @abstract
  #
  # @option options :peer_host [String,IPAddr]
  # @option options :peer_port [Fixnum]
  # @option options :local_host [String,IPAddr]
  # @option options :local_port [Fixnum]
  def create_udp(options)
    raise NotImplementedError
  end

  # Create a TCP server listening on :local_port
  #
  # @abstract
  #
  # @option options :local_host [String,IPAddr]
  # @option options :local_port [Fixnum]
  # @option options :ssl_context [OpenSSL::SSL::Context]
  def create_tcp_server(options)
    raise NotImplementedError
  end

  # Create a UDP server listening on :local_port
  #
  # @abstract
  #
  # @option options :local_host [String,IPAddr]
  # @option options :local_port [Fixnum]
  def create_udp_server(options)
    raise NotImplementedError
  end


end

