class String

  # @return [String]  `self` with 8-bit unsigned characters.
  def repack
    unpack( 'C*' ).pack( 'C*' )
  end

  # Forces `self` to UTF-8 and replaces invalid characters.
  def force_utf8!
    force_encoding( 'utf-8' )
    encode!( 'utf-16be', invalid: :replace, undef: :replace ).encode( 'utf-8' )
  end

  # @return [String]  Copy of `self`, {#force_utf8! forced to UTF-8}.
  def force_utf8
    dup.force_utf8!
  end

  # @return [Bool]
  #   `true` if `self` is binary, `false` if regular text.
  def binary?
    encoding == Encoding::ASCII_8BIT ||
        index( "\x00" ) ||
        count( "\x00-\x7F", "^ -~\t\r\n").fdiv( length ) > 0.3
  end

end
