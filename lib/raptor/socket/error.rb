
# Base class for all socket-related errors
class Raptor::Socket::Error < Raptor::Error
end

# Base class for errors that cause a connection to fail
class Raptor::Socket::Error::ConnectionError < Raptor::Socket::Error
end

# Raised when a socket receives no SYN/ACK before timeout
class Raptor::Socket::Error::ConnectionTimeout < Raptor::Socket::Error::ConnectionError
end

# Raised when a socket receives a RST during connect
class Raptor::Socket::Error::ConnectionRefused < Raptor::Socket::Error::ConnectionError
end

# Host reachability error.
#
# Occurs when the remote host cannot be reached.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Raptor::Socket::Error::HostUnreachable < Raptor::Socket::Error::ConnectionError
end

# Broken-pipe error.
#
# Occurs when a connection dies unexpectedly.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Raptor::Socket::Error::BrokenPipe < Raptor::Socket::Error
end


