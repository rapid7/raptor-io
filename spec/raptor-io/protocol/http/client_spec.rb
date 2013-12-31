#coding: utf-8
require 'spec_helper'
require 'raptor-io/socket'

describe RaptorIO::Protocol::HTTP::Client do

  before :all do
    WebServers.start :client_close_connection
    WebServers.start :client_https
    WebServers.start :client

    @url       = WebServers.url_for( :client )
    @https_url = WebServers.url_for( :client_https ).gsub( 'http', 'https' )
  end

  before( :each ) do
    RaptorIO::Protocol::HTTP::Request::Manipulators.reset
    RaptorIO::Protocol::HTTP::Request::Manipulators.library = manipulator_fixtures_path
  end

  let(:url) { 'http://test.com' }
  let(:switch_board) { RaptorIO::Socket::SwitchBoard.new }
  let(:options) { {} }
  subject(:client) do
    described_class.new(
      { switch_board: switch_board }.merge(options)
    )
  end

  describe '#initialize' do

    describe :ssl_version do
      let(:options) do
        { ssl_version: 'stuff' }
      end

      it 'sets the SSL version to use' do
        client.ssl_version.should == 'stuff'
      end
    end

    describe :ssl_verify_mode do
      let(:options) do
        { ssl_verify_mode: 'stuff' }
      end

      it 'sets the SSL version to use' do
        client.ssl_verify_mode.should == 'stuff'
      end
    end

    describe :ssl_context do
      let(:options) do
        { ssl_context: 'stuff' }
      end

      it 'sets the SSL version to use' do
        client.ssl_context.should == 'stuff'
      end
    end

    describe :manipulators do
      it 'defaults to an empty Hash' do
        client.manipulators.should == {}
      end

      context 'when the options are invalid' do
        it 'raises RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
          expect do
            described_class.new(
                switch_board: switch_board,
                manipulators: {
                  options_validator: { mandatory_string: 12 }
                }
            )
          end.to raise_error RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
        end
      end

      context 'with manipulators' do
        let(:manipulators) do
          { 'manifoolators/fooer' => { times: 15 } }
        end
        let(:options) do
          { manipulators: manipulators }
        end
        it 'sets the manipulators option' do
          client.manipulators.should == manipulators
        end

        context 'when a request is queued' do
          it 'runs the configured manipulators' do
            request = RaptorIO::Protocol::HTTP::Request.new( url: "#{@url}/" )
            client.queue( request )
            request.url.should == "#{@url}/" + ('foo' * 15)
          end
        end
      end
    end

    describe :timeout do
      context 'without a value' do
        it 'defaults to 10' do
          client.timeout.should == 10
        end
      end

      context 'with a value' do
        let(:options) do
          { timeout: 1 }
        end

        it 'sets the timeout option' do
          client.timeout.should == 1
        end

        context 'when a timeout occurs' do
          it 'raises RaptorIO::Error::Timeout', speed: 'slow' do
            expect {
              client.get( "#{@url}/sleep", mode: :sync )
            }.to raise_error RaptorIO::Error::Timeout
          end
        end
      end

    end

    describe :concurrency do
      context 'without a value' do
        it 'defaults to 20' do
          client.concurrency.should == 20
        end
      end
      context 'with a value' do
        let(:options) do
          { concurrency: 10 }
        end

        it 'sets the request concurrency option' do
          client.concurrency.should == 10
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
      end
    end

    describe :user_agent do
      context 'without a value' do
        it "defaults to 'RaptorIO::HTTP/#{RaptorIO::VERSION}'" do
          client.user_agent.should == "RaptorIO::HTTP/#{RaptorIO::VERSION}"
        end
      end

      context 'with a value' do
        let(:ua) { 'Stuff' }
        let(:options) do
          { user_agent: ua }
        end
        it 'sets the user-agent option' do
          client.user_agent.should == ua
        end

        it 'sets the User-Agent for the requests' do
          client.request( @url ).headers['User-Agent'].should == ua
        end

      end
    end
  end

  describe '#update_manipulators' do
    context 'when the options are invalid' do
      it 'raises RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
        expect do
          client.update_manipulators( options_validator: { mandatory_string: 12 } )
        end.to raise_error RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
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
    it 'supports SSL' do
      res = client.get( @https_url, mode: :sync )
      res.should be_kind_of RaptorIO::Protocol::HTTP::Response
      res.code.should == 200
      res.body.should == 'Stuff...'
    end

    it 'handles responses without body (1xx, 204, 304)' do
      client.get( "#{@url}/204", mode: :sync ).should be_kind_of RaptorIO::Protocol::HTTP::Response
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
        response = RaptorIO::Protocol::HTTP::Response.new( url: url )

        request = client.request( '/blah/' ) { |res| passed_response = res }
        request.handle_response( response )
        passed_response.should == response
      end
    end

    describe 'option' do
      describe :manipulators do
        context 'when the options are invalid' do
          it 'raises RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
            expect do
              client.get( "#{@url}/",
                          manipulators: { options_validator: { mandatory_string: 12 } }
              )
            end.to raise_error RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
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
              response.error.should be_kind_of RaptorIO::Error::Timeout
            end
          end

          2.times do
            client.get( "#{@url}/long-sleep", timeout: 3 ) do |response|
              response.error.should be_kind_of RaptorIO::Error::Timeout
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
          let (:options) do
            { timeout: 1 }
          end
          it 'raises RaptorIO::Error::Timeout', speed: 'slow' do
            expect {
              client.get( "#{@url}/sleep", mode: :sync )
            }.to raise_error RaptorIO::Error::Timeout
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
            response.should be_kind_of RaptorIO::Protocol::HTTP::Response
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
      client.request( '/blah/' ).should be_kind_of RaptorIO::Protocol::HTTP::Request
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
      client.queue( RaptorIO::Protocol::HTTP::Request.new( url: url ) )
      client.queue_size.should == 1
    end
    it 'returns the queued request' do
      request = RaptorIO::Protocol::HTTP::Request.new( url: url )
      client.queue(request).should == request
    end

    describe :manipulators do
      context 'when the options are invalid' do
        it 'raises RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions' do
          expect do
            request = RaptorIO::Protocol::HTTP::Request.new( url: "#{@url}/" )
            client.queue( request, options_validator: { mandatory_string: 12 } )
          end.to raise_error RaptorIO::Protocol::HTTP::Request::Manipulator::Error::InvalidOptions
        end
      end

      it 'loads and configures the given manipulators' do
        request = RaptorIO::Protocol::HTTP::Request.new( url: "#{@url}/" )
        client.queue( request, 'manifoolators/fooer' => { times: 10 } )
        request.url.should == "#{@url}/" + ('foo' * 10)
      end
    end

  end

  describe '#<<' do
    it 'alias of #queue' do
      client.queue_size.should == 0
      client << RaptorIO::Protocol::HTTP::Request.new( url: url )
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

          it 'assigns RaptorIO::Socket::Error::ConnectionError to #error' do
            url = 'http://localhost:9696969'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of RaptorIO::Socket::Error::ConnectionError
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

          it 'assigns RaptorIO::Socket::Error::ConnectionError to #error', speed: 'slow' do
            url = 'http://10.11.12.13'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of RaptorIO::Socket::Error::ConnectionError
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

          it 'assigns RaptorIO::Socket::Error::CouldNotResolve to #error' do
            url = 'http://stuffhereblahblahblah'

            response = nil
            client.get( url ){ |r| response = r }
            client.run

            response.error.should be_kind_of RaptorIO::Socket::Error::CouldNotResolve
          end
        end
      end

      context 'in synchronous mode' do
        context 'due to a closed port' do
          it 'raises RaptorIO::Socket::Error::ConnectionRefused' do
            expect {
              client.get( 'http://localhost:858589', mode: :sync )
            }.to raise_error RaptorIO::Socket::Error::ConnectionRefused
          end
        end

        context 'due to an invalid address' do
          it 'raises RaptorIO::Socket::Error::CouldNotResolve' do
            expect {
              client.get( 'http://stuffhereblahblahblah', mode: :sync )
            }.to raise_error RaptorIO::Socket::Error::CouldNotResolve
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
