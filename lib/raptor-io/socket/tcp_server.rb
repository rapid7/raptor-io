# A listening TCP socket
class RaptorIO::Socket::TCPServer < RaptorIO::Socket

  # @!method accept
  def_delegator :@socket, :accept, :accept

  # @!method accept_nonblock
  def_delegator :@socket, :accept_nonblock, :accept_nonblock

  # @!method bind
  def_delegator :@socket, :bind, :bind

  # @!method listen
  def_delegator :@socket, :listen, :listen

  # @!method ungetc
  def_delegator :@socket, :ungetc, :ungetc

end
