require 'singleton'
require 'net/http'

class WebServers
  include Singleton

  attr_reader :lib

  def initialize
    @lib     = File.expand_path( File.dirname(  __FILE__ ) + '/../webservers' )
    @servers = {}

    Dir.glob( File.join( @lib + '/**', '*.rb' ) ) do |path|
      @servers[normalize_name( File.basename( path, '.rb' ) )] = {
        port: available_port,
        path: path
      }
    end
  end

  def start( name )
    return if up?( name )

    server_info = data_for( name )
    server_info[:pid] = quite_fork {
      exec 'ruby', server_info[:path], '-p',  server_info[:port].to_s
    }

    sleep 0.2 while !up?( name )
  end

  def url_for( name )
    "#{protocol_for( name )}://#{address_for( name )}:#{port_for( name )}"
  end

  def address_for( name )
    '127.0.0.1'
  end

  def protocol_for( name )
    'http'
  end

  def port_for( name )
    data_for( name )[:port]
  end

  def target_for( name )
    WebTarget.new( address_for( name ), port_for( name ) )
  end

  def data_for( name )
    @servers[normalize_name( name )]
  end

  def up?( name )
    begin
      ::Net::HTTP.get_response( URI.parse( url_for( name ) ) )
      true
    rescue Errno::ECONNRESET
      true
    rescue => e
      false
    end
  end

  def kill( name )
    server_info = data_for( name )
    return if !server_info[:pid]

    begin
      10.times { Process.kill( 'KILL', server_info[:pid] ) }
      return false
    rescue Errno::ESRCH
      server_info.delete( :pid )
      return true
    end
  end

  def killall
    @servers.keys.each { |n| kill n }
  end

  def available_port
    loop do
      port = 5555 + rand( 9999 )
      begin
        socket = Socket.new( :INET, :STREAM, 0 )
        socket.bind( Addrinfo.tcp( '127.0.0.1', port ) )
        socket.close
        return port
      rescue Errno::EADDRINUSE => e
      end
    end
  end

  def normalize_name( name )
    name.to_s.to_sym
  end

  def self.method_missing( sym, *args, &block )
    if instance.respond_to?( sym )
      instance.send( sym, *args, &block )
    elsif
    super( sym, *args, &block )
    end
  end

  def self.respond_to?( m )
    super( m ) || instance.respond_to?( m )
  end

  private

  def set_data_for( name, data )
    @servers[normalize_name( name )] = data
  end

  def quite_fork( &block )
    pid = fork {
      $stdout.reopen( '/dev/null', 'w' )
      $stderr.reopen( '/dev/null', 'w' )
      block.call
    }
    Process.detach( pid )
    pid
  end
end
