
# Communication through a SAPRouter
#
# By default SAPRouter listens on port 3299.
#
# @see https://labs.mwrinfosecurity.com/blog/2012/09/13/sap-smashing-internet-windows/
# @see http://conference.hitb.org/hitbsecconf2010ams/materials/D2T2%20-%20Mariano%20Nunez%20Di%20Croce%20-%20SAProuter%20.pdf
class Raptor::Socket::Comm::SAPNI < Raptor::Socket::Comm

  # The bits of the packet that don't change
  NI_ROUTE_HEADER = [
    "NI_ROUTE",
    2,  # route info version
    39, # NI version
    2,  # number of entries
    1,  # talk mode (NI_MSG_IO: 0; NI_RAW_IO; 1; NI_ROUT_IO: 2)
    0,  # unused
    0,  # unused
    1,  # number of rest nodes
  ].pack("Z*C7")

  # @param options [Hash]
  # @option options :sap_host [String,IPAddr]
  # @option options :sap_port [Fixnum] (3299)
  # @option options :sap_comm [Comm]
  def initialize(options = {})
    @sap_host = options[:sap_host]
    @sap_port = (options[:sap_port] || 3299).to_i
    @sap_comm = options[:sap_comm]
  end

  # @param (see Comm#create_tcp)
  def create_tcp(options)
    @sap_socket = @sap_comm.create_tcp(
      peer_host: @sap_host,
      peer_port: @sap_port
    )

    first_route_item = [
      @sap_host, @sap_port.to_s, 0
    ].pack("Z*Z*C")

    second_route_item = [
      options[:peer_host], options[:peer_port].to_s, 0
    ].pack("Z*Z*C")

    route_data =
      # This is *not* a length, it is the
      #   "current position as an offset into the route string"
      # according to
      # http://help.sap.com/saphelp_nwpi711/helpdata/en/48/6a29785bed4e6be10000000a421937/content.htm
      [ first_route_item.length ].pack("N") +
      first_route_item +
      second_route_item
    route_data = [ route_data.length - 4 ].pack("N") + route_data

    ni_packet = NI_ROUTE_HEADER.dup + route_data
    ni_packet = [ni_packet.length].pack('N') + ni_packet

    p ni_packet

    @sap_socket.write(ni_packet)
    res_length = @sap_socket.read(4)
    res = @sap_socket.read(res_length.unpack("N").first)
    p res

    Raptor::Socket::TCP.new(@sap_socket, options)
  end

end

