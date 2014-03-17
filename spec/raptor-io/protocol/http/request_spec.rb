# coding: utf-8
require 'spec_helper'
require 'ostruct'

describe RaptorIO::Protocol::HTTP::Request do
  it_should_behave_like 'RaptorIO::Protocol::HTTP::Message'

  let(:url) { 'http://test.com' }
  let(:parsed_url) { URI(url) }
  let(:url_with_query) { 'http://test.com/?id=1&stuff=blah' }

  subject(:request) do
    described_class.new( options )
  end
  let(:options) { { url: url } }

  describe '#initialize' do
    it 'sets the instance attributes by the options' do
      options = {
          url: url,
          http_method: :get,
          parameters: { 'test' => 'blah' },
          timeout: 10,
          continue: false,
          raw: true
      }
      r = described_class.new( options )
      r.url.should          == url
      r.http_method.should  == options[:http_method]
      r.parameters.should   == options[:parameters]
      r.timeout.should      == options[:timeout]
      r.continue.should     == options[:continue]
      r.raw.should          == options[:raw]
    end

    context 'POST' do
      it 'content-type defaults to "application/x-www-form-urlencoded"' do
        options = { url: url, http_method: :post, }
        request = described_class.new( options )
        expect(request).to have_header('content-type')
        expect(request.headers['content-type']).to include("application/x-www-form-urlencoded")
      end
    end

    it 'uses the setter methods when configuring' do
      options = { url: url, http_method: 'gEt', parameters: { 'test' => 'blah' } }
      described_class.new( options ).http_method.should == :get
    end

    context 'when no :url option has been provided' do
      it 'raises ArgumentError' do
        raised = false
        begin
          described_class.new
        rescue ArgumentError
          raised = true
        end
        raised.should be_true
      end
    end
  end

  describe '#connection_id' do
    it 'returns an ID for the given host:port' do
      described_class.new( url: 'http://stuff' ).connection_id.should ==
        described_class.new( url: 'http://stuff:80' ).connection_id

      described_class.new( url: 'http://stuff' ).connection_id.should_not ==
          described_class.new( url: 'http://stuff:81' ).connection_id

      described_class.new( url: 'http://stuff.com' ).connection_id.should ==
          described_class.new( url: 'http://stuff.com' ).connection_id
    end
  end

  describe '#continue?' do
    context 'default' do
      it 'returns true' do
        described_class.new( url: url ).continue?.should be_true
      end
    end

    context 'when the continue option has been set to' do
      context true do
        it 'returns false' do
          described_class.new( url: url, continue: true ).continue?.should be_true
        end
      end

      context false do
        it 'returns false' do
          described_class.new( url: url, continue: false ).continue?.should be_false
        end
      end
    end
  end


  describe '#url' do
    it 'returns the configured value' do
      described_class.new( url: url ).url.should == url
    end
  end

  describe '#parsed_url' do
    it 'returns the configured URL as a parsed object' do
      described_class.new( url: url ).parsed_url.should == URI(url)
    end
  end

  describe '#http_method' do
    it 'defaults to :get' do
      described_class.new( url: url ).http_method.should == :get
    end
  end

  describe '#http_method=' do
    it 'normalizes the HTTP method to a downcase symbol' do
      request = described_class.new( url: url )
      request.http_method = 'pOsT'
      request.http_method.should == :post
    end
  end

  describe '#idempotent?' do
    context 'when http_method is post' do
      it 'returns false' do
        described_class.new( url: url, http_method: :post ).idempotent?.should be_false
      end
    end

    context 'when http_method is not post' do
      it 'returns true' do
        described_class.new( url: url ).idempotent?.should be_true
      end
    end
  end

  describe '#parameters' do
    it 'defaults to an empty Hash' do
      described_class.new( url: url ).parameters.should == {}
    end

    it 'recursively forces converts keys and values to strings' do
      with_symbols = {
          test:         'blah',
          another_hash: {
              stuff: 'test'
          }
      }
      with_strings = {
          'test'         => 'blah',
          'another_hash' => {
              'stuff' => 'test'
          }
      }

      request = described_class.new( url: url )
      request.parameters = with_symbols
      request.parameters.should == with_strings
    end
  end

  describe '#query_parameters' do
    context 'when :raw option is' do
      context true do
        it 'does not decode the URL query parameters' do
          weird_url = 'http://test.com/?first=test%3Fblah%2F&second%2F%26=blah'
          r = described_class.new( raw: true, url: weird_url, http_method: :other )
          r.query_parameters.should == { 'first' => 'test%3Fblah%2F', 'second%2F%26' => 'blah' }
        end
      end

      context false do
        it 'decodes the URL query parameters' do
          weird_url = 'http://test.com/?first=test%3Fblah%2F&second%2F%26=blah'
          r = described_class.new( raw: false, url: weird_url, http_method: :other )
          r.query_parameters.should == { 'first' => 'test?blah/', 'second/&' => 'blah' }
        end
      end

      context 'default' do
        it 'decodes the URL query parameters' do
          weird_url = 'http://test.com/?first=test%3Fblah%2F&second%2F%26=blah'
          r = described_class.new( url: weird_url, http_method: :other )
          r.query_parameters.should == { 'first' => 'test?blah/', 'second/&' => 'blah' }
        end
      end
    end

    context 'when the request method is' do
      context 'GET' do
        context 'when no parameters have been provided as options' do
          it 'returns the query parameters as a Hash' do
            r = described_class.new( url: url_with_query, http_method: :get )
            r.query_parameters.should == { 'id' => '1', 'stuff' => 'blah' }
          end
        end
        context 'when there are parameters as options' do
          let(:parameters) { { 'id' => '2', 'stuff' => 'blah' } }

          context 'and the URL has no query parameters' do
            it 'returns the parameters from options' do
              r = described_class.new( url: url, http_method: :get, parameters: parameters )
              r.query_parameters.should == parameters
            end
          end
        end
      end
      context 'other' do
        it 'returns the query parameters as a Hash' do
          r = described_class.new( url: url_with_query, http_method: :other )
          r.query_parameters.should == { 'id' => '1', 'stuff' => 'blah' }
        end
      end
    end
  end

  describe '#resource' do
    it 'returns the resource to be requested' do
      r = described_class.new( url: url, parameters: { 'first' => 'test?blah/', 'second/&' => 'blah' } )
      r.resource.to_s.should == '/?first=test%3Fblah%2F&second%2F%26=blah'
    end
  end

  describe '#effective_url' do
    context 'when :raw option is' do
      context true do
        it 'does not encode the URL query parameters' do
          r = described_class.new( raw: true, url: url, parameters: { 'first' => 'test?blah/', 'second/&' => 'blah' } )
          r.effective_url.to_s.should == 'http://test.com/?first=test?blah/&second/&=blah'
        end
      end

      context false do
        it 'encodes the URL query parameters' do
          r = described_class.new( raw: false, url: url, parameters: { 'first' => 'test?blah/', 'second/&' => 'blah' } )
          r.effective_url.to_s.should == 'http://test.com/?first=test%3Fblah%2F&second%2F%26=blah'
        end
      end

      context 'default' do
        it 'encodes the URL query parameters' do
          r = described_class.new( url: url, parameters: { 'first' => 'test?blah/', 'second/&' => 'blah' } )
          r.effective_url.to_s.should == 'http://test.com/?first=test%3Fblah%2F&second%2F%26=blah'
        end
      end
    end

    it 'has UTF8 support' do
      options = {
          url: url_with_query,
          parameters: {
              'test' => 'τεστ'
          }
      }
      described_class.new( options ).effective_url.to_s.should ==
          "http://test.com/?id=1&stuff=blah&test=%CF%84%CE%B5%CF%83%CF%84"
    end

    context 'when the request method is' do
      context 'GET' do
        context 'when no parameters have been provided as options' do
          it 'returns the original URL' do
            r = described_class.new( url: url_with_query, http_method: :get )
            r.effective_url.to_s.should == url_with_query
          end
        end
        context 'when there are parameters as options' do
          let(:parameters) { { 'id' => '2', 'stuff' => 'blah' } }

          context 'and the URL has no query parameters' do
            it 'returns a URL with the option parameters' do
              r = described_class.new( url: url, http_method: :get, parameters: parameters )
              r.effective_url.to_s.should == "#{url}/?id=2&stuff=blah"
            end
          end
          context 'and the URL has query parameters' do
            it 'returns the query parameters merged with the options parameters' do
              r = described_class.new( url: url_with_query, http_method: :get, parameters: parameters )
              r.effective_url.to_s.should == "#{url}/?id=2&stuff=blah"
            end
          end
        end
      end
      context 'other' do
        it 'returns the original URL' do
          r = described_class.new( url: url_with_query, http_method: :other )
          r.effective_url.to_s.should == url_with_query
        end
      end
    end
  end

  describe '#effective_body' do

    context 'when the Expect header field has been set' do
      subject do
        described_class.new(
          url: url,
          headers: {'Expect'=>'100-continue'}
        ).effective_body
      end
      it { should be_empty }
    end

    context 'when no body has been provided' do
      subject { described_class.new( url: url ).effective_body }
      it { should be_empty }
    end

  end

  describe '#clear_callbacks' do
    it 'clears all callbacks' do
      request.on_complete { |res| res }
      request.on_complete.size.should == 1

      request.on_success { |res| res }
      request.on_success.size.should == 1

      request.on_failure { |res| res }
      request.on_failure.size.should == 1

      request.clear_callbacks

      request.on_complete.should be_empty
      request.on_success.should be_empty
      request.on_failure.should be_empty
    end
  end

  describe '#on_complete' do
    context 'when passed a block' do
      it 'adds it as a callback to be passed the response' do
        passed_response = nil
        request.on_complete { |res| passed_response = res }

        response = RaptorIO::Protocol::HTTP::Response.new( url: url )
        request.handle_response( response )

        passed_response.should == response
      end

      it 'can add multiple callbacks' do
        passed_responses = []

        2.times do
          request.on_complete { |res| passed_responses << res }
        end

        response = RaptorIO::Protocol::HTTP::Response.new( url: url )
        request.handle_response( response )

        passed_responses.size.should == 2
        passed_responses.uniq.size.should == 1
        passed_responses.uniq.first.should == response
      end
    end

    it 'returns all relevant callbacks' do
      2.times do
        request.on_complete { |res| res }
      end
      request.on_complete.size.should == 2
    end
  end

  describe '#on_success' do
    context 'when passed a block' do
      it 'adds it as a callback to be called on a successful request' do
        passed_response = nil
        request.on_success { |res| passed_response = res }

        response = RaptorIO::Protocol::HTTP::Response.new( url: url, code: 200 )
        request.handle_response( response )

        passed_response.should == response
      end

      it 'can add multiple callbacks' do
        passed_responses = []

        2.times do
          request.on_success { |res| passed_responses << res }
        end

        response = RaptorIO::Protocol::HTTP::Response.new( url: url, code: 200 )
        request.handle_response( response )

        passed_responses.size.should == 2
        passed_responses.uniq.size.should == 1
        passed_responses.uniq.first.should == response
      end
    end

    it 'returns all relevant callbacks' do
      2.times do
        request.on_success { |res| res }
      end
      request.on_success.size.should == 2
    end
  end

  describe '#on_failure' do
    context 'when passed a block' do
      it 'adds a callback block to be called on a failed request' do
        passed_response = nil
        request.on_failure { |res| passed_response = res }

        response = RaptorIO::Protocol::HTTP::Response.new( url: url, code: 0 )
        request.handle_response( response )

        passed_response.should == response
      end

      it 'can add multiple callbacks' do
        passed_responses = []

        2.times do
          request.on_failure { |res| passed_responses << res }
        end

        response = RaptorIO::Protocol::HTTP::Response.new( url: url, code: 0 )
        request.handle_response( response )

        passed_responses.size.should == 2
        passed_responses.uniq.size.should == 1
        passed_responses.uniq.first.should == response
      end
    end

    it 'returns all relevant callbacks' do
      request = described_class.new( url: url )
      2.times do
        request.on_failure { |res| res }
      end
      request.on_failure.size.should == 2
    end
  end

  describe '#handle_response' do

    it 'assigns self as the #request attribute of the response' do
      passed_response = nil
      request.on_complete { |res| passed_response = res }

      response = RaptorIO::Protocol::HTTP::Response.new( url: url )
      request.handle_response( response )

      passed_response.request.should == request
    end

    context 'when a response is successful' do
      let(:response) { RaptorIO::Protocol::HTTP::Response.new( url: url, code: 200 ) }

      it 'calls #on_complete callbacks' do
        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'calls #on_success callbacks' do
        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_failure callbacks' do
        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
    end
    context 'when a request fails' do
      let(:response) { RaptorIO::Protocol::HTTP::Response.new( url: url, code: 0 ) }

      it 'calls #on_complete callbacks' do
        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_success callbacks' do
        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
      it 'calls #on_failure callbacks' do
        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
    end
  end

  describe '#to_s' do
    subject(:request_str) { described_class.new( options ).to_s }

    it 'includes a Host header' do
      request_str.split("\r\n").should include("Host: #{parsed_url.host}:#{parsed_url.port}")
    end

    context 'when the request method is' do
      context 'GET' do
        context 'when no parameters have been provided as options' do
          let(:options) { { url: url_with_query, http_method: :get } }
          it 'uses the original URL' do
            request_str.lines.first.should == "GET /?id=1&stuff=blah HTTP/1.1\r\n"
          end
        end
        context 'when there are parameters as options' do
          let(:parameters) { { 'id' => '2', 'stuff' => 'blah' } }

          context 'and the URL has no query parameters' do
            it 'uses the URL with the option parameters' do
              r = described_class.new( url: url, http_method: :get, parameters: parameters )
              r.to_s.lines.first.should == "GET /?id=2&stuff=blah HTTP/1.1\r\n"
            end
          end
          context 'and the URL has query parameters' do
            it 'uses the query parameters merged with the options parameters' do
              r = described_class.new( url: url_with_query, http_method: :get, parameters: parameters )
              r.to_s.lines.first.should == "GET /?id=2&stuff=blah HTTP/1.1\r\n"
            end
          end
        end
      end

      context 'POST' do
        let(:options) do
          {
            raw: true,
            url: url_with_query,
            http_method: :post,
            body: 'stuff=1&blah=test'
          }
        end
        it 'uses the original body' do
          request_str.split("\r\n").last.should == options[:body]
        end
      end

      context 'other' do
        let(:options) do
          {
            url: url_with_query,
            http_method: :other,
            body: 'stuff'
          }
        end
        it 'returns the original body' do
          request_str.split("\r\n").last.should == options[:body]
        end
        it 'returns the original URL' do
          request_str.lines.first.should == "OTHER /?id=1&stuff=blah HTTP/1.1\r\n"
        end
      end
    end

    context 'when headers' do
      context 'have been provided' do
        let(:options) do
          {
            url:     url,
            headers: {
              'X-Stuff' => "blah"
            }
          }
        end
        it 'escapes and includes them in the request' do
          described_class.new( options ).to_s.should ==
            "GET / HTTP/1.1\r\n" +
            "Host: #{parsed_url.host}:#{parsed_url.port}\r\n" +
            "X-Stuff: blah\r\n\r\n"
        end
      end
    end

    context 'when an HTTP method' do
      context 'has been provided' do
        let(:options) do
          {
            url:         url,
            http_method: :stuff
          }
        end
        it 'includes it the request' do
          request_str.lines.first.should == "STUFF / HTTP/1.1\r\n"
        end
      end
      context 'has not been provided' do
        it 'defaults to GET' do
          request_str.lines.first.should == "GET / HTTP/1.1\r\n"
        end
      end
    end

    context 'when an HTTP version' do
      context 'has been provided' do
        let(:options) do
          {
            url:     url,
            version: '2'
          }
        end
        it 'includes it the request' do
          request_str.lines.first.should == "GET / HTTP/2\r\n"
        end
      end

      context 'has not been provided' do
        it 'defaults to 1.1' do
          request_str.lines.first.should == "GET / HTTP/1.1\r\n"
        end
      end
    end

    context 'when there is a body' do
      let(:options) do
        {
          url:  url,
          body: "fds g45\#$ 6@ %y @^2\r\n"
        }
      end
      it 'sets the Content-Length header' do
        request_str.should ==
          "GET / HTTP/1.1\r\n" +
          "Host: #{parsed_url.host}:#{parsed_url.port}\r\n" +
          "Content-Length: 21\r\n" +
          "\r\n" +
          "fds g45\#$ 6@ %y @^2\r\n"
      end
    end

  end

  describe '.parse' do
    it 'parses a request string into a Request object' do
      request = <<EOTXT
GET /stuff?pname=pvalue HTTP/1.1
Host: localhost:88
User-Agent: Stuff agent
Cookie: cname=cvalue; c2name=c2value

body+here
EOTXT

      request = described_class.parse( request )
      request.url.should             == '/stuff?pname=pvalue'
      request.parsed_url.to_s.should == '/stuff?pname=pvalue'
      request.version.should         == '1.1'
      request.http_method.should     == :get
      request.body.should            == "body+here\n"
      request.headers.should         eq({
        'Host'       => 'localhost:88',
        'User-Agent' => 'Stuff agent',
        'Cookie'     => 'cname=cvalue; c2name=c2value'
      })

      request.headers.cookies.should == [
        {
          name: 'cname',
          value: 'cvalue',
          version: 0,
          port: nil,
          discard: nil,
          comment_url: nil,
          expires: nil,
          max_age: nil,
          comment: nil,
          secure: nil,
          path: nil,
          domain: nil
        },
        {
          name: 'c2name',
          value: 'c2value',
          version: 0,
          port: nil,
          discard: nil,
          comment_url: nil,
          expires: nil,
          max_age: nil,
          comment: nil,
          secure: nil,
          path: nil,
          domain: nil
        }
      ]
    end
  end

end
