require 'spec_helper'

describe Raptor::Protocol::HTTP::Client do

  let(:url) { 'http://test.com' }
  let(:client) { described_class.new( address: 'stuff.com' ) }

  describe '#request' do
    it 'forwards the given options to the Request object' do
      options = { parameters: { 'name' => 'value' }}
      client.request( '/blah/', options ).parameters.should == options[:parameters]
    end

    context 'when passed a block' do
      it 'sets it as a callback' do
        passed_response = nil
        response = Raptor::Protocol::HTTP::Response.new( url: url )

        request = client.request( '/blah/' ) { |res| passed_response = res }
        request.handle_response( response )
        passed_response.should == response
      end
    end

    it 'increments the queue size' do
      client.queue_size.should == 0
      client.request( '/blah/' )
      client.queue_size.should == 1
    end

    it 'returns the request' do
      client.request( '/blah/' ).should be_kind_of Raptor::Protocol::HTTP::Request
    end
  end

  describe '#get' do
    it 'queues a GET request' do
      client.get( '/blah/' ).http_method.should == :get
    end
  end

  describe '#post' do
    it 'queues a POST request' do
      client.post( '/blah/' ).http_method.should == :post
    end
  end

  describe '#queue_size' do
    it 'returns the amount of queued requests' do
      client.queue_size.should == 0
      10.times { client.request( '/' ) }
      client.queue_size.should == 10
    end
  end

  describe '#queue' do
    it 'queues a request' do
      client.queue_size.should == 0
      client.queue( Raptor::Protocol::HTTP::Request.new( url: url ) )
      client.queue_size.should == 1
    end
    it 'returns the queued request' do
      request = Raptor::Protocol::HTTP::Request.new( url: url )
      client.queue(request).should == request
    end
  end

  describe '#<<' do
    it 'alias of #queue' do
      client.queue_size.should == 0
      client << Raptor::Protocol::HTTP::Request.new( url: url )
      client.queue_size.should == 1
    end
  end

  describe '#run' do
    it 'runs all the queued requests'
  end
end
