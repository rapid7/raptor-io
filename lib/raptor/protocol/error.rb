module Raptor

#
# {Protocol} error namespace.
#
# All {Protocol} errors inherit from and live under it.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
#
class Protocol::Error < Error

  # {Protocol} connection refused error.
  #
  # Occurs when nothing is listening on the requested resource.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class ConnectionRefused < Error
  end

  # {Protocol} hostname resolution error.
  #
  # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
  class CouldNotResolve < Error
  end

end
end
