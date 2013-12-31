module RaptorIO
module Protocol::HTTP
class Request

module Manipulators
module Authenticators

if !const_defined?( :Negotiate )
  load File.dirname( __FILE__ ) + '/negotiate.rb'
end

#
# Implements HTTP NTLM authentication.
#
# @author Tasos Laskos
#
class NTLM < Negotiate

  def provider
    'NTLM'
  end

end

end
end
end
end
end
