
require 'forwardable'

class Raptor::Socket::SslTcp < Raptor::Socket::Tcp

  extend Forwardable
  def_delegators :@sock, :close, :closed?, :to_io

  def_delegator :@sock, :context,     :ssl_context
  def_delegator :@sock, :verify_mode, :ssl_verify_mode
  def_delegator :@sock, :version,     :ssl_version

  # Connect and initiate an SSL handshake.
  #
  # @param (See http://www.ruby-doc.org/stdlib-1.9.3/libdoc/socket/rdoc/Socket.html#method-i-connect)
  def connect(remote_sockaddr)
    @sock.connect(remote_sockaddr)

    ssl_client_connect

    # If we haven't raised yet, the stdlib docs say return 0
    0
  end

end
