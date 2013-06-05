require 'cgi'
require 'uri'

#
# HTTP protocol implementation.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
module Raptor::Protocol::HTTP
  CRLF             = "\r\n"
  CRLF_SIZE        = CRLF.size
  HEADER_SEPARATOR = CRLF * 2
end

require 'raptor/protocol/http/error'
require 'raptor/protocol/http/headers'
require 'raptor/protocol/http/message'
require 'raptor/protocol/http/request'
require 'raptor/protocol/http/response'
require 'raptor/protocol/http/client'
