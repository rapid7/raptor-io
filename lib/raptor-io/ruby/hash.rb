#
# Monkey-patches Ruby's stdlib `Hash` with a few convenience methods.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
class Hash

  # @return [Hash]
  #   Hash with +self+'s keys and values recursively converted to strings.
  def stringify
    stringified = {}

    each do |k, v|
      if v.is_a?( Hash )
        stringified[k.to_s] = v.stringify
      else
        stringified[k.to_s] = v.to_s
      end
    end

    stringified
  end

end
