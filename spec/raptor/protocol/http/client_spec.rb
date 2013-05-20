require 'spec_helper'

describe Raptor::Protocol::HTTP::Client do

  let(:url) { 'http://test.com' }
  let(:client) { described_class.new }

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

    describe 'option' do
      describe :mode do
        describe :sync do
          it 'performs the request synchronously and returns the response' do
            options = {
                parameters: { 'name' => 'value' },
                mode:       :sync
            }
            response = client.request( 'http://example.net', options )
            response.should be_kind_of Raptor::Protocol::HTTP::Response
            response.request.parameters.should == options[:parameters]
          end
        end
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

  describe '#concurrency' do
    it 'defaults to 20' do
      described_class.new.concurrency.should == 20
    end
  end

  describe '#concurrency=' do
    it 'restricts the amount of maximum open connections' do
      cnt   = 0
      times = 10

      url = 'http://example.net'

      client.concurrency = 1
      times.times do
        client.get url do
          cnt += 1
        end
      end

      t = Time.now
      client.run
      runtime_1 =  Time.now - t
      cnt.should == times

      cnt = 0
      client.concurrency = 20
      times.times do
        client.get url do
          cnt += 1
        end
      end

      t = Time.now
      client.run
      runtime_2 =  Time.now - t

      cnt.should == times
      runtime_1.should > runtime_2
    end
  end

  describe '#run' do
    context 'when a request fails' do
      context 'due to a closed port' do
        it 'passes the callback an empty response' do
          url = 'http://localhost'

          response = nil
          client.get( url ){ |r| response = r }
          client.run

          response.version.should == '1.1'
          response.code.should == 0
          response.message.should be_nil
          response.body.should be_empty
          response.headers.should == {}
        end
      end

      context 'due to an invalid address' do
        it 'passes the callback an empty response' do
          url = 'http://stuffhereblahblahblah'

          response = nil
          client.get( url ){ |r| response = r }
          client.run

          response.version.should == '1.1'
          response.code.should == 0
          response.message.should be_nil
          response.body.should be_empty
          response.headers.should == {}
        end
      end
    end

    it 'runs all the queued requests' do
      cnt   = 0
      times = 2

      times.times do
        client.get 'http://example.com' do |r|
          cnt += 1
        end
      end

      client.run
      cnt.should == times
    end

    it 'runs requests queued via callbacks' do
      url = 'http://example.com'
      called = false

      client.get url do
        client.get url do
          called = true
        end
      end
  
      client.run
      called.should be_true
    end
  end
end
