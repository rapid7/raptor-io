#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor'

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

connections = []

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
      socks_comm: Raptor::Socket::Comm::Local.new,
      socks_host: server_host,
      socks_port: (opts_hash["socksport"] || 1080).to_i,
    }
    comm = Raptor::Socket::Comm::SOCKS.new(socks_opts)
    create_opts = {
      peer_host: host,
      peer_port: port,
    }

  when "tcp"
    if address.length != 2 || address.include?(nil) || address.include?("")
      usage("Invalid #{type} address")
    end

    comm = Raptor::Socket::Comm::Local.new
    create_opts = {
      peer_host: address.first,
      peer_port: address.last,
    }

  when "stdio"
    connections << [ $stdin, $stdout ]
  else
    usage("Unknown address type: #{type}")
  end

  if comm
    tcp = comm.create_tcp(create_opts)
    connections << [ tcp, tcp ]
  end

end

readers = connections.map{|c| c[0]}
writers = connections.map{|c| c[1]}
until readers.empty?
  r,_,_ = select(connections.map{|c| c[0]})
  r.each do |rio|
    if rio.eof?
      readers.delete(rio)
      next
    end

    data = rio.readpartial(1024)
    #puts rio.inspect + "\n" + data
    puts "Read #{data.length} bytes from #{rio.inspect}"

    case rio
    when readers[0]
      writers[1].write(data)
    when readers[1]
      writers[0].write(data)
    end
  end
end

