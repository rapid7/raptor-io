#coding: utf-8
require 'spec_helper'

describe Raptor::Protocol::HTTP::Client do

  before :all do
    WebServers.start :client_close_connection
    WebServers.start :client
    @url = WebServers.url_for( :client )
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
    Raptor::Protocol::HTTP::Request::Manipulators.library = manipulator_fixtures_path
  end

  let(:url) { 'http://test.com' }
  let(:client) { described_class.new }

  describe '#initialize' do

    describe :manipulators do
      it 'defaults to an empty Hash' do
        described_class.new.manipulators.should == {}
      end

      context 'when the options are invalid' do
        it 'raises Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
          expect do
            described_class.new(
                manipulators: {options_validator: { mandatory_string: 12 }}
            )
          end.to raise_error Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
        end
      end

      it 'sets the manipulators option' do
        manipulators = { 'manifoolators/fooer' => { times: 15 } }
        described_class.new( manipulators: manipulators ).manipulators.should == manipulators
      end

      context 'when a request is queued' do
        it 'runs the configured manipulators' do
          manipulators = { 'manifoolators/fooer' => { times: 15 } }
          client = described_class.new( manipulators: manipulators )

          request = Raptor::Protocol::HTTP::Request.new( url: "#{@url}/" )
          client.queue( request )
          request.url.should == "#{@url}/" + ('foo' * 15)
        end
      end
    end
    describe :timeout do
      it 'sets the timeout option' do
        described_class.new( timeout: 15 ).timeout.should == 15
      end

      context 'when a timeout occurs' do
        it 'raises Raptor::Error::Timeout', speed: 'slow' do
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

    describe :concurrency do
      it 'sets the request concurrency option' do
        described_class.new( concurrency: 10 ).concurrency.should == 10
      end

      it 'sets the amount of maximum open connections at any given time', speed: 'slow' do
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

  describe '#update_manipulators' do
    context 'when the options are invalid' do
      it 'raises Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
        expect do
          client.update_manipulators( options_validator: { mandatory_string: 12 } )
        end.to raise_error Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
      end
    end

    it 'updates the client-wide manipulators' do
      manipulators = { 'manifoolators/fooer' => { times: 16 } }
      client.update_manipulators( manipulators )
      client.manipulators.should == manipulators
    end
  end

  describe '#datastore' do
    it 'returns a hash' do
      client.datastore.should == {}
    end

    it 'has empty hashes as default values' do
      client.datastore['stuff'].should == {}
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
    it 'handles responses without body (1xx, 204, 304)' do
      client.get( "#{@url}/204", mode: :sync ).should be_kind_of Raptor::Protocol::HTTP::Response
    end

    it 'properly transmits raw binary data' do
      client.get( "#{@url}/echo_body",
                  raw: true,
                  mode: :sync,
                  body: "\ff\ff"
      ).body.should == "\ff\ff"
    end

    it 'properly transmits raw multibyte data' do
      client.get( "#{@url}/echo_body",
                  raw: true,
                  mode: :sync,
                  body: 'τεστ'
      ).body.should == 'τεστ'
    end

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
      describe :manipulators do
        context 'when the options are invalid' do
          it 'raises Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
            expect do
              client.get( "#{@url}/",
                          manipulators: { options_validator: { mandatory_string: 12 } }
              )
            end.to raise_error Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
          end
        end

        it 'loads and configures the given manipulators' do
          request = client.get( "#{@url}/",
                                manipulators:  {
                                    'manifoolators/fooer' => { times: 10 }
                                }
          )
          request.url.should == "#{@url}/" + ('foo' * 10)
        end
      end

      describe :cookies do
        context Hash do
          it 'formats and sets request cookies' do
            client.get( "#{@url}/cookies",
                        cookies:  {
                            'name' => 'value',
                            'name2' => 'value2'
                        },
                        mode:     :sync
            ).body.should == 'name=value;name2=value2'
          end
        end

        context String do
          it 'sets request cookies' do
            client.get( "#{@url}/cookies",
                        cookies:  'name=value;name2=value2',
                        mode:     :sync
            ).body.should == 'name=value;name2=value2'
          end
        end

      end

      describe :continue do
        context 'default' do
          it 'handles responses with status "100" automatically' do
            body = 'stuff-here'
            client.get( "#{@url}/100",
                        headers:  {
                            'Expect' => '100-continue'
                        },
                        body:     body,
                        mode:     :sync
            ).body.should == body
          end
        end

        context true do
          it 'handles responses with status "100" automatically' do
            body = 'stuff-here'
            client.get( "#{@url}/100",
                        headers:  {
                            'Expect' => '100-continue'
                        },
                        body:     body,
                        continue: true,
                        mode:     :sync
            ).body.should == body
          end
        end

        context false do
          it 'does not handle responses with status "100" automatically' do
            body = 'stuff-here'
            client.get( "#{@url}/100",
                        headers:  {
                            'Expect' => '100-continue'
                        },
                        body:     body,
                        continue: false,
                        mode:     :sync
            ).code.should == 100
          end
        end
      end

      describe :timeout do
        it 'handles timeouts progressively and in groups', speed: 'slow' do

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 20 ) do |response|
              response.error.should be_nil
            end
          end

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 2 ) do |response|
              response.error.should be_kind_of Raptor::Error::Timeout
            end
          end

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 3 ) do |response|
              response.error.should be_kind_of Raptor::Error::Timeout
            end
          end

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 7 ) do |response|
              response.error.should be_nil
            end
          end

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 10 ) do |response|
              response.error.should be_nil
            end
          end

          t = Time.now
          client.run
          runtime = Time.now - t

          (runtime >= 5.0 || runtime < 6.0).should be_true
        end

        context 'when a timeout occurs' do
          it 'raises Raptor::Error::Timeout', speed: 'slow' do
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

    it 'treats a closed connection as a signal for end of a response' do
      url = WebServers.url_for( :client_close_connection )
      client.get( url, mode: :sync ).body.should == "Success\n.\n"
      client.get( url, mode: :sync ).body.should == "Success\n.\n"
      client.get( url, mode: :sync ).body.should == "Success\n.\n"
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
        it 'chunked', speed: 'slow' do
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

    describe :manipulators do
      context 'when the options are invalid' do
        it 'raises Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
          expect do
            request = Raptor::Protocol::HTTP::Request.new( url: "#{@url}/" )
            client.queue( request, options_validator: { mandatory_string: 12 } )
          end.to raise_error Raptor::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
        end
      end

      it 'loads and configures the given manipulators' do
        request = Raptor::Protocol::HTTP::Request.new( url: "#{@url}/" )
        client.queue( request, 'manifoolators/fooer' => { times: 10 } )
        request.url.should == "#{@url}/" + ('foo' * 10)
      end
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
            url = 'http://localhost:9696969'

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
            url = 'http://localhost:9696969'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of Raptor::Protocol::Error::ConnectionRefused
          end

        end

        context 'due to an invalid IP address' do
          it 'passes the callback an empty response', speed: 'slow' do
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

          it 'assigns Raptor::Protocol::Error::HostUnreachable to #error', speed: 'slow' do
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
          it 'raises Raptor::Protocol::Error::ConnectionRefused' do
            expect {
              client.get( 'http://localhost:858589', mode: :sync )
            }.to raise_error Raptor::Protocol::Error::ConnectionRefused
          end
        end

        context 'due to an invalid address' do
          it 'raises Raptor::Protocol::Error::CouldNotResolve' do
            expect {
              client.get( 'http://stuffhereblahblahblah', mode: :sync )
            }.to raise_error Raptor::Protocol::Error::CouldNotResolve
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
