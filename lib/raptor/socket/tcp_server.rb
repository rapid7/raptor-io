# A listening TCP socket
class Raptor::Socket::TcpServer < Raptor::Socket

  # Factory method for creating a new {TcpServer} through the given
  # {SwitchBoard `:switch_board`}
  #
  # @param (see Raptor::Socket::Comm.create)
  # @option (see Raptor::Socket::Comm.create)
  # @option opts :peer_host [String,IPAddr]
  # @option opts :peer_port [Fixnum]
  # @return [TcpServer]
  def self.create(opts)
    #required_keys = [ :local_host, :local_port ]
    #validate_opts(opts, required_keys)

    comm = opts[:switch_board].best_comm(opts[:peer_host])

    # copy so we don't modify the caller's stuff
    opts = opts.dup
    opts[:proto] = :tcp
    opts[:server] = true

    sock = comm.create(opts)

    new(sock)
  end

end
