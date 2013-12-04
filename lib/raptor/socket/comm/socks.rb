require 'timeout'
require 'socket'

# Communication through a SOCKS proxy
#
# @see http://openssh.org/txt/socks4.protocol
# @see https://tools.ietf.org/html/rfc1928
class Raptor::Socket::Comm::SOCKS < Raptor::Socket::Comm

  # @!attribute socks_host
  #   The SOCKS server's address
  #   @return [String]
  attr_accessor :socks_host
  # @!attribute socks_port
  #   The SOCKS server's port
  #   @return [Fixnum]
  attr_accessor :socks_port
  # @!attribute socks_comm
  #   The {Comm} used to connect to the SOCKS server
  #   @return [Comm]
  attr_accessor :socks_comm

  # Constants for address types ("ATYP" in the RFC)
  module AddressTypes
    # 4-byte IPv4 address
    ATYP_IPv4 = 1
    # DNS name as a Pascal string
    ATYP_DOMAINNAME = 3
    # 16-byte IPv6 address
    ATYP_IPv6 = 4
  end

  # Constants for reply codes
  module ReplyCodes
    # `X'00' succeeded`
    SUCCEEDED = 0
    # `X'01' general SOCKS server failure`
    GENERAL_FAILURE = 1
    # `X'02' connection not allowed by ruleset`
    NOT_ALLOWED = 2
    # `X'03' Network unreachable`
    NETUNREACH = 3
    # `X'04' Host unreachable`
    HOSTUNREACH = 4
    # `X'05' Connection refused`
    CONNREFUSED = 5
    # `X'06' TTL expired`
    TTL_EXPIRED = 6
    # `X'07' Command not supported`
    CMD_NOT_SUPPORTED = 7
    # `X'08' Address type not supported`
    ATYP_NOT_SUPPORTED = 8
  end

  def initialize(options = {})
    @socks_host = options[:socks_host]
    @socks_port = options[:socks_port].to_i
    @socks_comm = options[:socks_comm]
  end

  # (see Comm#support_ipv6?)
  def support_ipv6?
  end

  # (see Comm#resolve)
  def resolve(hostname)
  end

  # (see Comm#reverse_resolve)
  def reverse_resolve(ip_address)
  end

  # Connect to `:peer_host`
  #
  # @option (see Comm#create_tcp)
  # @option options :socks_host [String,IPAddr]
  # @option options :socks_port [Fixnum]
  #
  # @return [Socket::TCP]
  #
  # @raise [Raptor::Socket::Error::ConnectTimeout]
  def create_tcp(options)
    @socks_socket = socks_comm.create_tcp(
      peer_host: socks_host,
      peer_port: socks_port
    )

    negotiate_connection(options[:peer_host], options[:peer_port])

    Raptor::Socket::TCP.new(@socks_socket, options)
  end


  private

  # Attempt to create a connection to `peer_host`:`peer_port` via the
  # SOCKS server at {#socks_host}:{#socks_port}.
  #
  # @param peer_host [String] An address or hostname
  # @param peer_port [Fixnum] TCP port to connect to
  #
  # @raise [Error::ConnectionError] When the connection fails
  def negotiate_connection(peer_host, peer_port)
    # From RFC1928:
    # ```
    #   o  X'00' NO AUTHENTICATION REQUIRED
    #   o  X'01' GSSAPI
    #   o  X'02' USERNAME/PASSWORD
    #   o  X'03' to X'7F' IANA ASSIGNED
    #   o  X'80' to X'FE' RESERVED FOR PRIVATE METHODS
    #   o  X'FF' NO ACCEPTABLE METHODS
    # ```
    auth_methods = [ 0 ]
    # [ version ][ N methods ][ methods ... ]
    v5_pkt = [ 5, auth_methods.count, *auth_methods ].pack("CCC*")

    @socks_socket.write(v5_pkt)
    response = @socks_socket.read(2)

    case response
    when "\x05\x00".force_encoding('binary')
      # Then they accepted NO AUTHENTICATION and we can send a connect
      # request *without* a password
      request = pack_v5_connect_packet(peer_host, peer_port.to_i)
    else
      # Then they didn't like what we had to offer.
      @socks_socket.close
      raise Raptor::Socket::Error::ConnectionError, "Proxy connection failed"
    end

    @socks_socket.write(request)

    # [ version ][ reply code ][ reserved ][ atyp ]
    reply_pkt = @socks_socket.read(4)
    _, reply, _, type = reply_pkt.unpack("C4")

    #  X'00' succeeded
    #  X'01' general SOCKS server failure
    #  X'02' connection not allowed by ruleset
    #  X'03' Network unreachable
    #  X'04' Host unreachable
    #  X'05' Connection refused
    #  X'06' TTL expired
    #  X'07' Command not supported
    #  X'08' Address type not supported
    #  X'09' to X'FF' unassigned
    case reply
    when ReplyCodes::SUCCEEDED
      # Read in the bind addr. The protocol spec says this is supposed
      # to be the getsockname(2) address of the sockfd on the server,
      # which isn't all that useful to begin with. SSH(1) always
      # populates it with NULL bytes, making it completely pointless.
      # Read it off the socket and ignore it so it doesn't get in the
      # way of the proxied traffic.
      case type
      when AddressTypes::ATYP_IPv4
        @socks_socket.read(4)
      when AddressTypes::ATYP_IPv6
        @socks_socket.read(16)
      when AddressTypes::ATYP_DOMAINNAME
        # Pascal string, so read in the length and then read that many
        len = @socks_socket.read(1).to_i
        @socks_socket.read(len)
      end
      # bind port
      @socks_socket.read(2)

    when ReplyCodes::NETUNREACH, ReplyCodes::HOSTUNREACH
      @socks_socket.close
      raise Raptor::Socket::Error::HostUnreachable
    when ReplyCodes::CONNREFUSED
      @socks_socket.close
      raise Raptor::Socket::Error::ConnectionRefused
    when ReplyCodes::GENERAL_FAILURE,
         ReplyCodes::NOT_ALLOWED,
         ReplyCodes::TTL_EXPIRED,
         ReplyCodes::CMD_NOT_SUPPORTED,
         ReplyCodes::ATYP_NOT_SUPPORTED
      # Then this is a kind of failure that doesn't map well to standard
      # socket errors. Just call it a ConnectionError.
      @socks_socket.close
      raise Raptor::Socket::Error::ConnectionError
    else
      # Then this is an unassigned error code. No idea what it is, so
      # just call it a ConnectionError
      @socks_socket.close
      raise Raptor::Socket::Error::ConnectionError
    end
  end

  def pack_v5_connect_packet(peer_host, peer_port)
    begin
      ip = IPAddr.parse(peer_host)
      if ip.ipv4?
        type = AddressTypes::ATYP_IPv4
      elsif ip.ipv6?
        type = AddressTypes::ATYP_IPv6
      end
      packed_addr = ip.hton
    rescue ArgumentError
      type = AddressTypes::ATYP_DOMAINNAME
      # Packed as a Pascal string
      packed_addr = [peer_host.length, peer_host].pack("Ca*")
    end
    connect_packet = [
      5, # Version
      1, # CMD, CONNECT X'01'
      0, # reserved
      type,
      packed_addr,
      peer_port
    ].pack("CCCCa*n")

    connect_packet
  end

end

