require 'ipaddr'
require 'raptor-io/ruby/ipaddr'

#
# A logical switch board route.
#
class RaptorIO::Socket::SwitchBoard::Route
  include Comparable

  # @param subnet [String,IPAddr]  The network associated with this
  #   route. If specified as a String, must be parseable by IPAddr.new
  # @param netmask [String,IPAddr] `subnet`'s netmask. If specified as
  #   a String, must be parseable by IPAddr.new
  # @param comm [Comm] The endpoint where sockets for this route
  #   should be created.
  def initialize(subnet, netmask, comm)
    self.netmask = IPAddr.parse(netmask)
    self.subnet  = IPAddr.parse(subnet).mask netmask.to_s
    self.comm    = comm
  end

  #
  # For direct equality, make sure all the attributes are the same
  #
  def ==(other)
    return false unless other.kind_of? RaptorIO::Socket::SwitchBoard::Route
    netmask == other.netmask && subnet == other.subnet && comm == other.comm
  end

  #
  # For comparison, sort according to netmask.
  #
  # This allows {Route routes} to be ordered by specificity
  #
  def <=>(other)
    netmask <=> other.netmask
  end

  attr_reader :subnet, :netmask, :comm
protected
  attr_writer :subnet, :netmask, :comm
end
