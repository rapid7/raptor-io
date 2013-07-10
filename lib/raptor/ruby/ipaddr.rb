
class IPAddr
  def self.parse(parse_me)
    ret = if parse_me.kind_of?(IPAddr)
            parse_me
          else
            IPAddr.new(parse_me)
          end

    ret
  end
end

