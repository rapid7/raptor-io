require 'thread'
require 'raptor-io/socket'
require 'base64'
require 'cgi'
require 'uri'

#
# HTTP protocol implementation.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
module RaptorIO::Protocol::HTTP

  # Matches line separator characters for HTTP messages.
  CRLF_PATTERN             = /\r?\n/

  # CRLF character sequence.
  CRLF                     = "\r\n"

  # Matches sequence used to separate headers from the body.
  HEADER_SEPARATOR_PATTERN = /\r?\n\r?\n/

  # Header separator character sequence.
  HEADER_SEPARATOR         = "\r\n\r\n"

end

require 'raptor-io/protocol/http/error'
require 'raptor-io/protocol/http/headers'
require 'raptor-io/protocol/http/message'
require 'raptor-io/protocol/http/request'
require 'raptor-io/protocol/http/response'
require 'raptor-io/protocol/http/server'
require 'raptor-io/protocol/http/client'
