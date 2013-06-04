require 'spec_helper'

describe Raptor::Protocol::HTTP::Client do

  before :all do
    WebServers.start :client
    @url = WebServers.url_for( :client )
  end

  let(:url) { 'http://test.com' }
  let(:client) { described_class.new }

  describe '#initialize' do

    describe :timeout do
      it 'sets the timeout option' do
        described_class.new( timeout: 15 ).timeout.should == 15
      end

      context 'when a timeout occurs' do
        it 'raises Raptor::Error::Timeout' do
          client = described_class.new( timeout: 1 )
          expect {
            client.get( "#{@url}/sleep", mode: :sync )
          }.to raise_error Raptor::Error::Timeout
        end
      end

      it 'defaults to 10' do
        described_class.new.timeout.should == 10
      end
    end

    describe :max_redirects do
      it 'sets the max_redirects option' do
        described_class.new( max_redirections: 10 ).max_redirections.should == 10
      end

      it 'sets the limit on how many stacked redirections to follow' do
        client = described_class.new( max_redirections: 6 )
        response = client.get( "#{@url}/redirect_10_times", mode: :sync )
        response.redirections.size.should == 6
        response.headers['Location'].should == "#{@url}/redirect_3_times"
      end

      it 'defaults to 5' do
        described_class.new.max_redirections.should == 5
      end
    end

    describe :username do
      context 'when the password option is missing' do
        it 'raises ArgumentError' do
          expect { described_class.new( password: 'stuff' ) }.to raise_error ArgumentError
        end
      end
    end

    describe :password do
      context 'when the username option is missing' do
        it 'raises ArgumentError' do
          expect { described_class.new( password: 'stuff' ) }.to raise_error ArgumentError
        end
      end
    end

    describe :concurrency do
      it 'sets the request concurrency option' do
        described_class.new( concurrency: 10 ).concurrency.should == 10
      end

      it 'sets the amount of maximum open connections at any given time' do
        cnt   = 0
        times = 10

        url = "#{@url}/sleep"

        client.concurrency = 1
        times.times do
          client.get url do
            cnt += 1
          end
        end

        t = Time.now
        client.run
        runtime_1 = Time.now - t
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

      it 'defaults to 20' do
        client.concurrency.should == 20
      end
    end

    describe :user_agent do
      it 'sets the user-agent option' do
        described_class.new( user_agent: 'Stuff' ).user_agent.should == 'Stuff'
      end

      it 'sets the User-Agent for the requests' do
        ua = 'Stuff'
        client = described_class.new( user_agent: ua )
        client.request( @url ).headers['User-Agent'].should == ua
      end

      it "defaults to 'Raptor::HTTP/#{Raptor::VERSION}'" do
        client.user_agent.should == "Raptor::HTTP/#{Raptor::VERSION}"
      end
    end
  end

  context 'when credentials are given' do
    it 'uses them to connect to a restricted resource' do
      client.get( "#{@url}/basic-auth", mode: :sync ).code.should == 401

      client = described_class.new( username: 'admin', password: 'secret' )
      client.get( "#{@url}/basic-auth", mode: :sync ).code.should == 200
    end
  end

  describe '#concurrency=' do
    it 'sets the concurrency option' do
      client.concurrency.should_not == 10
      client.concurrency = 10
      client.concurrency.should == 10
    end
  end

  describe '#user_agent=' do
    it 'sets the user_agent option' do
      ua = 'stuff'
      client.user_agent.should_not == ua
      client.user_agent = ua
      client.user_agent.should == ua
    end
  end

  describe '#request' do
    it 'forwards the given options to the Request object' do
      options = { parameters: { 'name' => 'value' }}
      client.request( '/blah/', options ).parameters.should == options[:parameters]
    end

    context 'when using HTTP/1.1' do
      it 'signals that is does not support persistent connections' do
        client.request( '/blah/' ).headers['Connection'].should == 'close'
      end

      context 'otherwise' do
        it 'does not' do
          client.request( '/blah/', version: '1.0' ).headers.should_not include 'Connection'
        end
      end

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
      describe :timeout do
        context 'when a timeout occurs' do
          it 'raises Raptor::Error::Timeout' do
            client = described_class.new( timeout: 1 )
            expect {
              client.get( "#{@url}/sleep", mode: :sync )
            }.to raise_error Raptor::Error::Timeout
          end
        end
      end
      describe :mode do
        describe :sync do
          it 'performs the request synchronously and returns the response' do
            options = {
                parameters: { 'name' => 'value' },
                mode:       :sync
            }
            response = client.request( @url, options )
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

    describe 'Content-Encoding' do
      it 'supports gzip' do
        client.get( "#{@url}/gzip", mode: :sync ).body.should == 'gzip'
      end

      it 'supports deflate' do
        client.get( "#{@url}/deflate", mode: :sync ).body.should == 'deflate'
      end
    end

    describe 'Content-Encoding' do
      context 'supports' do
        it 'chunked' do
          res = client.get( "#{@url}/chunked", mode: :sync )
          res.body.should == "foo\nbara\rbaraf\r\n"
          res.headers.should_not include 'Transfer-Encoding'
          res.headers['Content-Length'].to_i.should == res.body.size
        end
      end
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
    context 'when a request fails' do
      context 'in asynchronous mode' do
        context 'due to a closed port' do
          it 'passes the callback an empty response' do
            url = 'http://localhost'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.version.should == '1.1'
            response.code.should == 0
            response.message.should be_nil
            response.body.should be_nil
            response.headers.should == {}
          end

          it 'assigns Raptor::Protocol::Error::ConnectionRefused to #error' do
            url = 'http://localhost'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of Raptor::Protocol::Error::ConnectionRefused
          end

        end

        context 'due to an invalid IP address' do
          it 'passes the callback an empty response' do
            url = 'http://10.11.12.13'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.version.should == '1.1'
            response.code.should == 0
            response.message.should be_nil
            response.body.should be_nil
            response.headers.should == {}
          end

          it 'assigns Raptor::Protocol::Error::HostUnreachable to #error' do
            url = 'http://10.11.12.13'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of Raptor::Protocol::Error::HostUnreachable
          end
        end

        context 'due to an invalid hostname' do
          it 'passes the callback an empty response' do
            url = 'http://stuffhereblahblahblah'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.version.should == '1.1'
            response.code.should == 0
            response.message.should be_nil
            response.body.should be_nil
            response.headers.should == {}
          end

          it 'assigns Raptor::Protocol::Error::CouldNotResolve to #error' do
            url = 'http://stuffhereblahblahblah'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of Raptor::Protocol::Error::CouldNotResolve
          end
        end
      end

      context 'in synchronous mode' do
        context 'due to a closed port' do
          it 'raises an exception' do
            expect { client.get( 'http://localhost', mode: :sync ) }.to raise_error
          end
        end

        context 'due to an invalid address' do
          it 'raises an exception' do
            expect { client.get( 'http://stuffhereblahblahblah', mode: :sync ) }.to raise_error
          end
        end
      end

    end

    it 'runs all the queued requests' do
      cnt   = 0
      times = 2

      times.times do
        client.get @url do |r|
          cnt += 1
        end
      end

      client.run
      cnt.should == times
    end

    it 'runs requests queued via callbacks' do
      called = false
      client.get @url do
        client.get @url do
          called = true
        end
      end

      client.run
      called.should be_true
    end
  end
end
