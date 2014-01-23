#!/usr/bin/env ruby

$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'
require 'uri'

def usage(msg = nil)
  file = File.basename(__FILE__)
  if msg
    $stderr.puts
    $stderr.puts "ERROR: #{msg}"
  end
  $stderr.puts
  $stderr.puts "Usage: #{file} <proxy uri> <proxy uri> ... <tcp|ssl uri>"
  $stderr.puts
  $stderr.puts "Examples:"
  $stderr.puts %q^   # Create a local socks server tunneling through remote host^
  $stderr.puts %q^   # example.com; on *that* host, create a local socks server^
  $stderr.puts %q^   # that tunnels through a second host, example.org^
  $stderr.puts %q^   ssh example.com -D 1080 -T "ssh example.org -vnNT -D 1080"^
  $stderr.puts %q^   # Connect to www.google.com via both of the proxies created above^
  $stderr.puts %Q^   #{file} socks://127.0.0.1:1080 socks://127.0.0.1:1080 ssl://www.google.com:443^
  $stderr.puts
  exit 1
end

if ARGV.length == 0 || !((ARGV & ["-h", "--help"]).empty?)
  usage
end

comms = [ RaptorIO::Socket::Comm::Local.new ]

last_uri = URI.parse(ARGV.pop)

connect_opts = case last_uri.scheme.downcase
               when "tcp"
                 {
                   peer_host: last_uri.host,
                   peer_port: last_uri.port,
                 }
               when "ssl"
                 {
                   peer_host: last_uri.host,
                   peer_port: last_uri.port,
                   ssl_context: OpenSSL::SSL::SSLContext.new(:TLSv1),
                 }
               else
                 usage("Last uri must be for a tcp:// or ssl:// connection")
               end

comm_chain = RaptorIO::Socket::CommChain.new(*ARGV)
sock = comms.last.create_tcp(connect_opts)

readers = [ sock, $stdin ]
writers = [ $stdout, sock ]

# Now build a list of reader,writer tuples
connections = readers.zip(writers)

until connections.empty?
  r,_,_ = RaptorIO::Socket.select(connections.map(&:first))
  r.each do |read_io|
    begin
      data = read_io.readpartial(1024)
    rescue EOFError
      connections.delete_if { |c| (c.first == read_io) }
      next
    end
    tuple = connections.find { |c| c.first == read_io }
    tuple.last.write(data)
  end
end

