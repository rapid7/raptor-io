require 'ipaddr'

class IPAddr

  # @param [String, IPAddr] parse_me Object to parse.
  # @return [IPAddr]
  def self.parse(parse_me)
    if parse_me.kind_of?(IPAddr)
      parse_me
    else
      IPAddr.new(parse_me)
    end
  end
end

