#coding: utf-8
require 'spec_helper'

describe Raptor::Protocol::HTTP::Server do

  after :each do
    @server.stop
  end

  def test_server( server_or_url )
    test_request server_or_url
  end

  def test_request( server_or_url )
    request( server_or_url ).code.should == '418'
  end

  def request( server_or_url )
    Net::HTTP.get_response( URI( argument_to_url( server_or_url ) ) )
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

  describe '#initialize' do
    describe :address do
      it 'binds to this address' do
        address = Socket.gethostbyname( Socket.gethostname ).first
        @server = described_class.new(
            address: address
        )
        @server.address.should == address
        @server.run_nonblock

        test_server @server

        expect { request( "http://localhost:#{@server.port}/" ) }.to raise_error Errno::ECONNREFUSED
      end

      it 'defaults to 0.0.0.0' do
        @server = described_class.new
        @server.address.should == '0.0.0.0'

        @server.run_nonblock

        test_server @server
      end
    end

    describe :port do
      it 'binds to this port' do
        @server = described_class.new( port: 8080 )
        @server.port.should == 8080
        @server.run_nonblock

        test_server @server
      end

      it 'defaults to 4567' do
        @server = described_class.new
        @server.port.should == 4567

        @server.run_nonblock

        test_server @server
      end
    end

    describe :timeout do
      it 'defaults to 10', speed: 'slow' do
        @server = described_class.new
        @server.timeout.should == 10
        @server.run_nonblock

        @server.timeouts.should == 0

        socket = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
        sockaddr = Socket.pack_sockaddr_in( @server.port, @server.address )
        socket.connect( sockaddr )

        sleep 9

        @server.timeouts.should == 0

        sleep 11
        socket.close

        @server.timeouts.should == 1
      end

      it 'sets the request timeout' do
        @server = described_class.new( timeout: 1 )
        @server.timeout.should == 1
        @server.run_nonblock

        @server.timeouts.should == 0

        socket = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
        sockaddr = Socket.pack_sockaddr_in( @server.port, @server.address )
        socket.connect( sockaddr )

        sleep 2
        socket.close

        @server.timeouts.should == 1
      end
    end

    describe :request_mtu do
      it 'reads bodies larger than :request_mtu in :request_mtu sized chunks' do
        @server = described_class.new( request_mtu: 1 )
        @server.request_mtu.should == 1
        @server.run_nonblock

        test_request_with_body @server
      end
    end

    describe :response_mtu do
      it 'sends responses larger than :response_mtu in :response_mtu sized chunks' do
        @server = described_class.new( response_mtu: 1 )
        @server.response_mtu.should == 1
        @server.run_nonblock

        test_request_with_body @server
      end
    end

    describe :handler do
      it 'passes each request to the given handler' do
        request = nil

        @server = described_class.new do |response|
          request       = response.request
          response.code = 200
          response.body = 'Success!'
        end

        @server.run_nonblock

        response = request( @server )
        response.code.should == '200'
        response.body.should == 'Success!'

        request.should be_kind_of Raptor::Protocol::HTTP::Request
      end
    end
  end

  describe '#run' do
    it 'starts the server' do
      @server = described_class.new
      Thread.new { @server.run }
      sleep 0.1 while !@server.running?

      test_server @server
    end
  end

  describe '#run_nonblock' do
    it 'starts the server but does not block' do
      @server = described_class.new
      @server.run_nonblock

      test_server @server
    end
  end

  describe '#running?' do
    context 'when the server is running' do
      it 'returns true' do
        @server = described_class.new
        @server.run_nonblock
        @server.running?.should be_true
      end
    end
    context 'when the server is not running' do
      it 'returns true' do
        @server = described_class.new
        @server.running?.should be_false
      end
    end
  end

  describe '#stop' do
    it 'stops the server' do
      @server = described_class.new
      @server.run_nonblock

      test_server @server
      @server.stop

      expect { request( @server ) }.to raise_error Errno::ECONNREFUSED
    end
  end

  describe '#url' do
    it 'returns the URL of the server' do
      @server = described_class.new
      @server.run_nonblock

      @server.url.should == "http://#{@server.address}:#{@server.port}/"
      test_server @server.url
    end
  end

end
