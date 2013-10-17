require 'raptor'
require 'rack'
require 'stringio'
require 'rack/content_length'

# Rack handler for {Raptor::Protocol::HTTP::Server}.
class Rack::Handler::Raptor

  Rack::Handler.register self.to_s.split( ':' ).last.downcase, self

  # Starts the server and runs the `app`.
  #
  # @param  [#call] app   Rack Application to run.
  # @param  [Hash]  options Rack options.
  def self.run( app, options = {} )
    return false if @server

    options[:address]  = options.delete(:Host) || default_host
    options[:port]   ||= options.delete(:Port) || 8080

    @app    = app
    @server = ::Raptor::Protocol::HTTP::Server.new( options ) do |response|
      service response
    end
    yield @server if block_given?
    @server.run

    true
  end

  # Shuts down the server.
  def self.shutdown
    return false if !@server

    @server.stop
    @server = nil

    true
  end

  private

  def self.valid_options
    {
        'Host=HOST' => "Hostname to listen on (default: #{default_host})",
        'Port=PORT' => 'Port to listen on (default: 8080)'
    }
  end

  def self.default_host
    (ENV['RACK_ENV'] || 'development') == 'development' ? 'localhost' : '0.0.0.0'
  end

  def self.service( response )
    request      = response.request
    path         = request.effective_url.path
    http_version = "HTTP/#{request.version}"

    query_string = request.effective_url.to_s.split( '?' ).last.to_s
    query_string = '' if query_string == '/'

    environment = {
        'REQUEST_METHOD'  => request.http_method.to_s.upcase,
        'SCRIPT_NAME'     => '',
        'PATH_INFO'       => path,
        'PATH_INFO'       => path,
        'REQUEST_PATH'    => path,
        'QUERY_STRING'    => query_string,
        'SERVER_NAME'     => @server.address,
        'SERVER_PORT'     => @server.port.to_s,
        'HTTP_VERSION'    => http_version,
        'REMOTE_ADDR'     => request.client_address
    }

    request.headers.each do |k, v|
      environment["HTTP_#{k.upcase.gsub( '-', '_' )}"] = v
    end

    if environment['HTTP_CONTENT_TYPE']
      environment['CONTENT_TYPE'] = environment.delete( 'HTTP_CONTENT_TYPE' )
    end

    if environment['HTTP_CONTENT_LENGTH']
      environment['CONTENT_LENGTH'] = environment.delete( 'HTTP_CONTENT_LENGTH' )
    end

    environment['SERVER_PROTOCOL'] = environment['HTTP_VERSION']

    rack_input = StringIO.new( request.body.to_s )
    rack_input.set_encoding( Encoding::BINARY ) if rack_input.respond_to?( :set_encoding )

    environment.update(
        'rack.version'      => Rack::VERSION,
        'rack.input'        => rack_input,
        'rack.errors'       => $stderr,
        'rack.multithread'  => true,
        'rack.multiprocess' => false,
        'rack.run_once'     => false,
        'rack.url_scheme'   => 'http',
        'rack.hijack?'      => false,
        'raptor.request'    => request
    )

    begin
      status, headers, body = @app.call( environment )
      body = '' if !body

      response.code = status

      if body.is_a? String
        response.body = body
      else
        body.each { |part| (response.body ||= '') << part }
      end

      response.headers.merge! headers
    rescue RuntimeError => e
      response.code = 501
      response.body = "#{e} (#{e.class})"

      environment['rack.errors'].puts "#{e} (#{e.class})"
      e.backtrace.each do |line|
        environment['rack.errors'].puts line
      end

      response.headers['content-type'] = 'text/plain'
    end
  ensure
    body.close if body.respond_to? :close
  end
end
