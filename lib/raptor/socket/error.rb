# Base class for all socket-related errors
class Raptor::Socket::Error < Raptor::Error

  # Hostname resolution error.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class CouldNotResolve < Raptor::Socket::Error
  end

  # Base class for errors that cause a connection to fail.
  class ConnectionError < Raptor::Socket::Error
  end

  # Raised when a socket receives no SYN/ACK before timeout.
  class ConnectionTimeout < Raptor::Socket::Error::ConnectionError
  end

  # Raised when a socket receives a RST during connect.
  class ConnectionRefused < Raptor::Socket::Error::ConnectionError
  end

  # Host reachability error.
  #
  # Occurs when the remote host cannot be reached.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class HostUnreachable < Raptor::Socket::Error::ConnectionError
  end

  # Broken-pipe error.
  #
  # Occurs when a connection dies unexpectedly.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class BrokenPipe < Raptor::Socket::Error
  end

  # Not connected error.
  #
  # Occurs when attempting to transmit data over a not connected transport endpoint.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class NotConnected < Raptor::Socket::Error
  end
end
