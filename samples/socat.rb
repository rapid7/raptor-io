#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'

def usage(msg)
  $stderr.puts "ERROR: #{msg}"
  $stderr.puts
  $stderr.puts "Usage:"
  $stderr.puts __FILE__ + " <address> <address>"
  $stderr.puts
  $stderr.puts "Addresses can be specified as:"
  $stderr.puts "    SOCKS:<server-host>:<host>:<port>"
  $stderr.puts "    TCP:<host>:<port>"
  $stderr.puts "    STDIO"
  $stderr.puts
  $stderr.puts "The SOCKS address type has additional options."
  $stderr.puts
  $stderr.puts "Examples:"
  $stderr.puts "    SOCKS:127.0.0.1:www.google.com:80,socksport=1234"
  $stderr.puts
  exit 1
end

if ARGV.length != 2
  usage("Wrong number of addresses (#{ARGV.length} for 2)")
end

readers = []
writers = []

ARGV.each do |address|
  address, options = address.split(",", 2)
  address = address.split(":")
  type = address.shift

  opts_hash = {}
  if options
    opts_hash = options
      .split(",")
      .map{|a| a.split("=",2)}
      .reduce({}) { |a, e| a[e.first] = e.last; a }
  end

  case type.downcase
  when "socks"
    if address.length != 3 || address.include?(nil) || address.include?("")
      usage("Invalid #{type} address")
    end

    server_host, host, port = address
    socks_opts = {
      socks_comm: RaptorIO::Socket::Comm::Local.new,
      socks_host: server_host,
      socks_port: (opts_hash["socksport"] || 1080).to_i,
    }
    comm = RaptorIO::Socket::Comm::SOCKS.new(socks_opts)
    create_opts = {
      peer_host: host,
      peer_port: port,
    }

  when "openssl","ssl"
    if address.length != 2 || address.include?(nil) || address.include?("")
      usage("Invalid #{type} address")
    end

    if opts_hash["method"]
      ssl_version = case opts_hash["method"].downcase
                    when "sslv2"  then :SSLv2
                    when "sslv3"  then :SSLv3
                    when "sslv23" then :SSLv23
                    when "tlsv1"  then :TLSv1
                    else usage("Invalid ssl version (possible values: sslv2,sslv3,sslv23,tlsv1)")
                    end
    else
      ssl_version = :TLSv1
    end

    ssl_context = OpenSSL::SSL::SSLContext.new(ssl_version)
    ssl_context.verify_mode = (opts_hash["verify"] == "0" ?
                               OpenSSL::SSL::VERIFY_NONE :
                               OpenSSL::SSL::VERIFY_PEER)

    comm = RaptorIO::Socket::Comm::Local.new
    create_opts = {
      peer_host: address.first,
      peer_port: address.last,
      ssl_context: ssl_context,
    }
    $stderr.puts ssl_context.inspect

  when "tcp"
    if address.length != 2 || address.include?(nil) || address.include?("")
      usage("Invalid #{type} address")
    end

    comm = RaptorIO::Socket::Comm::Local.new
    create_opts = {
      peer_host: address.first,
      peer_port: address.last,
    }

  when "stdio"
    readers.push($stdin)
    writers.unshift($stdout)
  else
    usage("Unknown address type: #{type}")
  end

  if comm
    tcp = comm.create_tcp(create_opts)
    readers.push(tcp)
    writers.unshift(tcp)
  end

end

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

