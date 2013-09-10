require 'spec_helper'
require 'rack/handler/raptor'

class RackValidatorApp
  def call( environment )

    environment.delete( 'rack.input' ).class.should == StringIO
    environment.delete( 'rack.errors' ).class.should == IO

    request = environment.delete( 'raptor.request' )

    http_version = environment.delete( 'HTTP_VERSION' )

    http_version.should == 'HTTP/1.1'
    environment.delete( 'SERVER_NAME' ).should  == environment['HTTP_HOST'].split( ':' ).first

    environment.dup.each do |k, v|
      next if !k.start_with?( 'HTTP_' )

      environment.delete( k ).should ==
          request.headers[ k.gsub( 'HTTP_', '' ).gsub( '_', '-' ) ]
    end

    environment.should == ({
      'REQUEST_METHOD'    => 'GET',
      'SCRIPT_NAME'       => '',
      'PATH_INFO'         => '/',
      'REQUEST_PATH'      => '/',
      'QUERY_STRING'      => '',
      'SERVER_PORT'       => '9292',
      'SERVER_PROTOCOL'   => http_version,
      'REMOTE_ADDR'       => '127.0.0.1',
      'rack.version'      => [ 1, 2 ],
      'rack.multithread'  => true,
      'rack.multiprocess' => false,
      'rack.run_once'     => false,
      'rack.url_scheme'   => 'http',
      'rack.hijack?'      => false
    })

    [ 200, { 'Content-Type' => 'text/html' }, 'Hello Rack!' ]
  end
end

class ErrorRackApp
  def call( environment )
    raise 'Stuff'
  end
end

describe Rack::Handler::Raptor do

  def argument_to_url( server_or_url )
    server_or_url.is_a?( String ) ? server_or_url : server_or_url.url
  end

  def request( server_or_url )
    Net::HTTP.get_response( URI( argument_to_url( server_or_url ) ) )
  end

  describe '.run' do
    it 'starts the server' do
      server = nil
      t = Thread.new do
        described_class.run( RackValidatorApp.new, Port: 9292 ) { |s| server = s }
      end
      sleep 1

      request( server ).body.should == 'Hello Rack!'

      described_class.shutdown
      t.join
    end

    context 'when the Rack application raises an exception' do
      it 'returns the error in the response body' do
        server = nil
        t = Thread.new do
          described_class.run( ErrorRackApp.new, Port: 9292 ) { |s| server = s }
        end
        sleep 1

        request( server ).body.should == 'Stuff (RuntimeError)'

        described_class.shutdown
        t.join
      end
    end
  end

  describe '.shutdown' do
    it 'stops the server' do
      server = nil
      t = Thread.new do
        described_class.run( RackValidatorApp.new, Port: 9292 ) { |s| server = s }
      end
      sleep 1

      request( server ).body.should == 'Hello Rack!'

      described_class.shutdown
      t.join

      expect { request( server ) }.to raise_error Errno::ECONNREFUSED
    end
  end

  describe '.default_host' do
    context 'by default' do
      it 'returns localhost' do
        described_class.default_host.should == 'localhost'
      end
    end

    context 'when RACK_ENV is' do
      context 'development' do
        it 'returns localhost' do
          ENV['RACK_ENV'] = 'development'
          described_class.default_host.should == 'localhost'
        end
      end

      context 'else' do
        it 'returns 0.0.0.0' do
          ENV['RACK_ENV'] = 'stuff'
          described_class.default_host.should == '0.0.0.0'
        end
      end
    end
  end


end
