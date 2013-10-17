require 'thread'
require 'raptor/socket'
require 'base64'
require 'cgi'
require 'uri'

#
# HTTP protocol implementation.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
module Raptor::Protocol::HTTP

  # Matches line separator characters for HTTP messages.
  CRLF_PATTERN             = /\r?\n/

  # CRLF character sequence.
  CRLF                     = "\r\n"

  # Matches sequence used to separate headers from the body.
  HEADER_SEPARATOR_PATTERN = /\r?\n\r?\n/

  # Header separator character sequence.
  HEADER_SEPARATOR         = "\r\n\r\n"

end

require 'raptor/protocol/http/error'
require 'raptor/protocol/http/headers'
require 'raptor/protocol/http/message'
require 'raptor/protocol/http/request'
require 'raptor/protocol/http/response'
require 'raptor/protocol/http/server'
require 'raptor/protocol/http/client'
