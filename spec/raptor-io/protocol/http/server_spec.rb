#coding: utf-8
require 'spec_helper'
require 'net/https'

describe RaptorIO::Protocol::HTTP::Server do

  after :each do
    next if !@server
    @server.stop
    @server = nil
  end

  def test_server( server_or_url )
    test_request server_or_url
  end

  def test_request( server_or_url )
    request( server_or_url ).code.should == '418'
  end

  def request( server_or_url )
    uri = URI( argument_to_url( server_or_url ) )

    https = Net::HTTP.new( uri.host, uri.port )
    https.use_ssl = (uri.scheme == 'https')
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    https.start { |cx| cx.request( Net::HTTP::Get.new( uri.path ) ) }
  end

  def test_request_with_body( server_or_url )
    response = request_with_body( server_or_url )
    response.code.should == '418'
    response.body.should == 'name=value'
  end

  def request_with_body( server_or_url )
    Net::HTTP.post_form( URI( argument_to_url( server_or_url ) ), 'name' => 'value' )
  end

  def argument_to_url( server_or_url )
    server_or_url.is_a?( String ) ? server_or_url : server_or_url.url
  end

  let(:switch_board) { RaptorIO::Socket::SwitchBoard.new }
  let(:ssl_context) do
    ssl_context             = OpenSSL::SSL::SSLContext.new( :TLSv1 )
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

    ca  = OpenSSL::X509::Name.parse( "/C=US/ST=SomeState/L=SomeCity/O=Organization/OU=Unit/CN=localhost" )
    key = OpenSSL::PKey::RSA.new( 1024 )
    crt = OpenSSL::X509::Certificate.new

    crt.version = 2
    crt.serial  = 1
    crt.subject = ca
    crt.issuer  = ca
    crt.public_key = key.public_key
    crt.not_before = Time.now
    crt.not_after  = Time.now + 1 * 365 * 24 * 60 * 60 # 1 year

    ssl_context.cert = crt
    ssl_context.key  = key
    ssl_context
  end

  def new_server( options = {}, &block )
    @server = described_class.new(
        { switch_board: switch_board }.merge(options),
        &block
    )
  end

  describe '#run_nonblock' do
    it 'starts the server but does not block' do
      server = new_server
      server.run_nonblock

      test_server server
    end
  end

  describe '#stop' do
    it 'stops the server' do
      server = new_server
      server.run_nonblock

      test_server server
      server.stop

      expect { request( server ) }.to raise_error Errno::ECONNREFUSED
    end
  end

  context 'when a request has Transfer-Encoding' do
    context 'other' do
      it 'returns a 501 response' do
        server = new_server
        server.run_nonblock

        socket = TCPSocket.new( server.address, server.port )
        [
            'GET / HTTP/1.1',
            'Transfer-Encoding: Stuff'
        ].each do |l|
          socket.puts l
        end
        socket.puts

        [
            'Data' * 12,
            'More data' * 20,
            'Even more data'  * 102
        ].each do |l|
          socket << "#{l.size.to_s( 16 )}\r\n#{l}\r\n"
        end
        socket << "0\r\n\r\n"

        buff = ''
        while !(buff =~ RaptorIO::Protocol::HTTP::HEADER_SEPARATOR_PATTERN)
          buff << socket.gets
        end
        socket.close

        RaptorIO::Protocol::HTTP::Response.parse( buff ).code.should == 501
      end
    end

    describe 'Chunked' do
      it 'supports it' do
        server = new_server
        server.run_nonblock

        socket = TCPSocket.new( server.address, server.port )
        [
            'GET / HTTP/1.1',
            'Transfer-Encoding: Chunked'
        ].each do |l|
          socket.puts l
        end
        socket.puts

        [
            'Data' * 12,
            'More data' * 20,
            'Even more data'  * 102
        ].each do |l|
          socket << "#{l.size.to_s( 16 )}\r\n#{l}\r\n"
        end
        socket << "0\r\n\r\n"

        buff = ''
        while !(buff =~ RaptorIO::Protocol::HTTP::HEADER_SEPARATOR_PATTERN)
          buff << socket.gets
        end
        socket.close

        RaptorIO::Protocol::HTTP::Response.parse( buff ).code.should == 418
      end
    end
  end

  describe '#initialize' do
    describe :switch_board do
      it 'uses that switchboard' do
        server = described_class.new( switch_board: switch_board )
        server.switch_board.should == switch_board
      end

      context 'when nil' do
        it 'raises ArgumentError' do
          expect { described_class.new }.to raise_error ArgumentError
        end
      end
    end

    describe :ssl_context do
      it 'uses it to establish an SSL stream' do
        server = new_server( ssl_context: ssl_context )
        server.url.should == "https://#{server.address}:#{server.port}/"
        server.ssl?.should be_true

        server.run_nonblock

        test_server server
      end
    end

    describe :address do
      it 'binds to this address' do
        address = '127.0.0.1'
        server = new_server( address: address )
        server.address.should == address
        server.run_nonblock

        test_server server
      end

      it 'defaults to 0.0.0.0' do
        server = new_server
        server.address.should == '0.0.0.0'

        server.run_nonblock

        test_server server
      end
    end

    describe :port do
      it 'binds to this port (8080)' do
        server = new_server( port: 8080 )
        server.port.should == 8080
        server.run_nonblock

        test_server server
      end

      it 'defaults to 4567' do
        server = new_server
        server.port.should == 4567

        server.run_nonblock

        test_server server
      end
    end

    describe :timeout do
      it 'defaults to 10' do
        server = new_server
        server.timeout.should == 10
      end

      it 'sets the request timeout', speed: 'slow' do
        server = new_server( timeout: 2 )
        server.timeout.should == 2
        server.run_nonblock

        server.timeouts.should == 0

        socket = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
        sockaddr = Socket.pack_sockaddr_in( server.port, server.address )
        socket.connect( sockaddr )

        sleep 1
        server.timeouts.should == 0
        sleep 3
        server.timeouts.should == 1

        socket.close
      end
    end

    describe :request_mtu do
      it 'reads bodies larger than :request_mtu in :request_mtu sized chunks' do
        server = new_server( request_mtu: 1 )
        server.request_mtu.should == 1
        server.run_nonblock

        test_request_with_body server
      end
    end

    describe :response_mtu do
      it 'sends responses larger than :response_mtu in :response_mtu sized chunks' do
        server = new_server( response_mtu: 1 )
        server.response_mtu.should == 1
        server.run_nonblock

        test_request_with_body server
      end
    end

    describe :handler do
      it 'passes each request to the given handler' do
        request = nil

        server = new_server do |response|
          request       = response.request
          response.code = 200
          response.body = 'Success!'
        end

        server.run_nonblock

        response = request( server )
        response.code.should == '200'
        response.body.should == 'Success!'

        request.should be_kind_of RaptorIO::Protocol::HTTP::Request
      end
    end
  end

  describe '#run' do
    it 'starts the server' do
      server = new_server
      Thread.new { server.run }
      sleep 0.1 while !server.running?

      test_server server
    end
  end

  describe '#running?' do
    context 'when the server is running' do
      it 'returns true' do
        server = new_server
        server.run_nonblock
        server.running?.should be_true
      end
    end
    context 'when the server is not running' do
      it 'returns true' do
        server = new_server
        server.running?.should be_false
      end
    end
  end

  describe '#url' do
    it 'returns the URL of the server' do
      server = new_server
      server.run_nonblock

      server.url.should == "http://#{server.address}:#{server.port}/"
      test_server server.url
    end
  end

end
