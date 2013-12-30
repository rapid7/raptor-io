# A listening TCP socket
class Raptor::Socket::TCPServer < Raptor::Socket::TCP

  # @!method accept
  def_delegator :@socket, :accept, :accept

  # @!method accept_nonblock
  def_delegator :@socket, :accept_nonblock, :accept_nonblock

end
