# -*- coding: binary -*-

require 'thread'

###
#
# A routing table that associates subnets with {Comm} objects.  Comm
# classes are used to instantiate objects that are tied to remote
# network entities.  For example, {Comm::Local} is used to build network
# connections directly from the local machine whereas, for instance, a
# Meterpreter Comm would build a local socket pair that is associated
# with a connection established by a remote entity.  This can be seen as
# a uniform way of communicating with hosts through arbitrary channels.
#
###
class Raptor::Socket::SwitchBoard

  require 'raptor/socket/comm'
  require 'raptor/socket/switch_board/route'

  include Enumerable

  DEFAULT_ROUTE = Route.new("0.0.0.0", "0.0.0.0", Raptor::Socket::Comm::Local)

  attr_reader :routes

  def initialize
    @routes = Array.new
    @mutex  = Mutex.new
  end

  #
  # Adds a route for a given subnet and netmask destined through a given comm
  # instance.
  #
  # @param (see Raptor::Socket::SwitchBoard::Route#new)
  # @return [Boolean] Whether the route already {#route_exists? existed}.
  def add_route(subnet, netmask, comm)
    rv = true

    @mutex.synchronize {
      # If the route already exists, return false to the caller.
      if (route_exists?(subnet, netmask))
        rv = false
      else
        @routes << Route.new(subnet, netmask, comm)
      end
    }

    rv
  end

  #
  # Finds the best possible comm for the supplied target address.
  #
  # @param addr [String,IPAddr]
  # @return [Comm]
  def best_comm(addr)
    addr = addr.kind_of?(IPAddr) ? addr : IPAddr.new(addr)

    addr_nbo = addr.to_i

    best_route = reduce(DEFAULT_ROUTE) { |best, route|
      if route.subnet.include?(addr) && route.netmask >= best.netmask
        route
      else
        best
      end
    }

    best_route.comm
  end

  #
  # Enumerates each entry in the routing table.
  #
  def each(&block)
    @routes.each(&block)
  end

  alias each_route each

  #
  # Flushes all established routes.
  #
  # @return [void]
  def flush_routes
    # Remove each of the individual routes so the comms don't think they're
    # still routing after a flush.
    @routes.each { |r|
      if r.comm.respond_to? :routes
        r.comm.routes.delete("#{r.subnet}/#{r.netmask}")
      end
    }

    # Re-initialize to an empty array
    @routes.clear
  end

  #
  # Remove all routes that go through the supplied `comm`.
  #
  # @param comm [Comm]
  # @return [void]
  def remove_by_comm(comm)
    @mutex.synchronize {
      @routes.delete_if { |route|
        route.comm == comm
      }
    }
    nil
  end

  #
  # Removes a route for a given subnet and netmask destined through a given
  # comm instance.
  #
  # @param (see Route.new)
  # @return [Boolean] Whether we found one to delete
  def remove_route(subnet, netmask, comm)
    rv = false

    other = Route.new(subnet, netmask, comm)
    @mutex.synchronize {
      @routes.delete_if { |route|
        if (route == other)
          rv = true
        else
          false
        end
      }
    }

    rv
  end

  #
  # Checks to see if a route already exists for the supplied subnet and
  # netmask.
  #
  def route_exists?(subnet, netmask)
    each { |route|
      return true if (route.subnet == subnet and route.netmask == netmask)
    }

    false
  end

protected

  attr_writer :routes # :nodoc:

end

