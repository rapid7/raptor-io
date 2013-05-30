
module Raptor

#
# Represents a Raptor error base-class and also provides the namespace for all
# Raptor errors.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Error < StandardError

# {Raptor} timeout error.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Timeout < Error
end

end
end
