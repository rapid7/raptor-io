
require 'forwardable'

# An SSL stream over TCP
class Raptor::Socket::SslTcp < Raptor::Socket::Tcp

  extend Forwardable
  def_delegators :@sock, :close, :closed?, :to_io

  # @!method ssl_context
  #   @return [OpenSSL::SSL::Context]
  def_delegator :@sock, :context, :ssl_context

  # @!method ssl_verify_mode
  #   @return [Fixnum] One of the OpenSSL::SSL::VERIFY_* constants
  def_delegator :@sock, :verify_mode, :ssl_verify_mode

  # @!method ssl_version
  #   @return [Symbol] One of the OpenSSL::SSL::VERIFY_* constants
  def_delegator :@sock, :version, :ssl_version

end
