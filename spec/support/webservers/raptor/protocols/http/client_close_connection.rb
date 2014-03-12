# Provides a test case for:
#   http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4
#
# Response will not include a Content-Length but rather close the connection to
# indicate the end of the response body.

require 'socket'
require_relative '../../../../../support/lib/webserver_option_parser'

BODY = "Success\n.\n"

options = WebServerOptionParser.parse

server = TCPServer.new( options[:address], options[:port] )
@requests = Hash.new { |h, k| h[k] = '' }

Thread.abort_on_exception = true
puts "Listening for connections"
loop do
  Thread.start( server.accept ) do |client|
    # Wait for the request to arrive.
    loop do
      break if (@requests[client] << client.gets.to_s).include?( "\r\n\r\n" )
    end

    client << "HTTP/1.1 200 OK\r\n\r\n"
    client << BODY
    client.close
  end
end
