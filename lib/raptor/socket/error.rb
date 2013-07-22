
# Base class for all socket-related errors
class Raptor::Socket::Error < StandardError; end

# Base class for errors that cause a connection to fail
class Raptor::Socket::ConnectionError < Raptor::Socket::Error; end

# Raised when a socket receives no SYN/ACK before timeout
class Raptor::Socket::ConnectionTimeout < Raptor::Socket::ConnectionError; end

# Raised when a socket receives a RST during connect
class Raptor::Socket::ConnectionRefused < Raptor::Socket::ConnectionError; end


