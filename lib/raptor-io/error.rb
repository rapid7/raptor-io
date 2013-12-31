
module RaptorIO

#
# Represents a RaptorIO error base-class and also provides the namespace for all
# RaptorIO errors.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Error < StandardError

# {RaptorIO} timeout error.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Timeout < Error
end

end
end
