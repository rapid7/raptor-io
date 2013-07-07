require 'optparse'

class WebServerOptionParser
  DEFAULT = {
      address: '0.0.0.0',
      port:    4567
  }

  def self.parse
    options = {}

    OptionParser.new do |opts|

      opts.on( '-o', '--addr [host]', "set the host (default is #{options[:address]})" ) do |address|
        options[:address] = address
      end

      opts.on( '-p', '--port [port]', Integer, "set the port (default is #{options[:port]})" ) do |port|
        options[:port] = port
      end

    end.parse!

    DEFAULT.merge( options )
  end
end
