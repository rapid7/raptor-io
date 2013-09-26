require 'thread'
require 'socket'
require 'base64'
require 'cgi'
require 'uri'

#
# HTTP protocol implementation.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
#
module Raptor::Protocol::HTTP
  CRLF_PATTERN             = /\r?\n/
  CRLF                     = "\r\n"
  HEADER_SEPARATOR_PATTERN = /\r?\n\r?\n/
  HEADER_SEPARATOR         = "\r\n\r\n"
end

require 'raptor/protocol/http/error'
require 'raptor/protocol/http/headers'
require 'raptor/protocol/http/message'
require 'raptor/protocol/http/request'
require 'raptor/protocol/http/response'
require 'raptor/protocol/http/server'
require 'raptor/protocol/http/client'
