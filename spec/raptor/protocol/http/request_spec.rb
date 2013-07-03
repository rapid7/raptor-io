# coding: utf-8
require 'spec_helper'
require 'ostruct'

describe Raptor::Protocol::HTTP::Request do
  it_should_behave_like 'Raptor::Protocol::HTTP::Message'

  let(:url) { 'http://test.com' }
  let(:parsed_url) { URI(url) }
  let(:url_with_query) { 'http://test.com/?id=1&stuff=blah' }

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
          context 'and the URL has query parameters' do
            it 'returns the query parameters merged with the options parameters' do
              r = described_class.new( url: url_with_query, http_method: :get, parameters: parameters )
              r.query_parameters.should == { 'id' => '1', 'stuff' => 'blah' }.merge(parameters)
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
      it 'returns an empty string' do
        described_class.new( url: url,
                             body: 'stuff',
                             headers: { 'Expect' => '100-continue' }
        ).effective_body.should == ''
      end
    end

    context 'when no body has been provided' do
      it 'returns an empty string' do
        described_class.new( url: url ).effective_body.should == ''
      end
    end

    context 'when there is a body' do
      context 'when :raw option is' do
        context true do
          it 'does not encode it' do
            options = {
                raw:  true,
                url:  url,
                body: "fds g45\#$ 6@ %y @^2\r\n"
            }
            described_class.new( options ).effective_body.should ==
                options[:body]
          end
        end

        context false do
          it 'encodes it' do
            options = {
                raw:  false,
                url:  url,
                body: "fds g45\#$ 6@ %y @^2\r\n"
            }
            described_class.new( options ).effective_body.should ==
                'fds+g45%23%24+6%40+%25y+%40%5E2%0D%0A'
          end
        end

        context 'default' do
          it 'encodes it' do
            options = {
                url:  url,
                body: "fds g45\#$ 6@ %y @^2\r\n"
            }
            described_class.new( options ).effective_body.should ==
                'fds+g45%23%24+6%40+%25y+%40%5E2%0D%0A'
          end
        end
      end

      it 'has UTF8 support' do
        described_class.new( url: 'http://stuff', body: 'τεστ' ).effective_body.should == '%CF%84%CE%B5%CF%83%CF%84'
      end
    end

    context 'when the request method is' do
      context 'POST' do
        context 'when no parameters have been provided as options' do
          context 'when :raw option is' do
            context true do
              it 'returns the original body' do
                options = {
                    raw: true,
                    url: url_with_query,
                    http_method: :post,
                    body: 'stuff=/1&blah=/test'
                }
                described_class.new( options ).effective_body.should == options[:body]
              end
            end

            context false do
              it 'escapes and returns the body' do
                options = {
                    raw: false,
                    url: url_with_query,
                    http_method: :post,
                    body: 'stuff=/1&blah=/test'
                }
                described_class.new( options ).effective_body.should == 'stuff=%2F1&blah=%2Ftest'
              end
            end

            context 'default' do
              it 'escapes and returns the body' do
                options = {
                    raw: false,
                    url: url_with_query,
                    http_method: :post,
                    body: 'stuff=/1&blah=/test'
                }
                described_class.new( options ).effective_body.should == 'stuff=%2F1&blah=%2Ftest'
              end
            end
          end
        end

        context 'when there are parameters as options' do
          let(:parameters) { { 'id/' => '2', 'stuff' => 'blah/' } }

          context 'and there is no body configured' do
            context 'when :raw option is' do
              context true do
                it 'returns the option parameters' do
                  options = {
                      raw: true,
                      url: url_with_query,
                      http_method: :post,
                      parameters: parameters
                  }
                  described_class.new( options ).effective_body.to_s.should ==
                      "id/=2&stuff=blah/"
                end
              end

              context false do
                it 'returns the escaped option parameters' do
                  options = {
                      raw: false,
                      url: url_with_query,
                      http_method: :post,
                      parameters: parameters
                  }
                  described_class.new( options ).effective_body.to_s.should ==
                      "id%2F=2&stuff=blah%2F"
                end
              end

              context 'default' do
                it 'returns the escaped option parameters' do
                  options = {
                      raw: false,
                      url: url_with_query,
                      http_method: :post,
                      parameters: parameters
                  }
                  described_class.new( options ).effective_body.to_s.should ==
                      "id%2F=2&stuff=blah%2F"
                end
              end
            end

          end

          it 'has UTF8 support' do
            options = {
                url: url_with_query,
                http_method: :post,
                parameters: {
                    'test' => 'τεστ'
                }
            }
            described_class.new( options ).effective_body.to_s.should ==
                "test=%CF%84%CE%B5%CF%83%CF%84"
          end

          context 'and there is a body' do
            it 'returns the body parameters merged with the options parameters' do
              options = {
                  url: url_with_query,
                  http_method: :post,
                  body: 'stuff 4354%$43=$#535!35VWE g4 %yt5&stuff=1',
                  parameters: parameters
              }
              described_class.new( options ).effective_body.to_s.should ==
                  "stuff+4354%25%2443=%24%23535%2135VWE+g4+%25yt5&stuff=blah%2F&id%2F=2"
            end
          end
        end
      end

      context 'other' do
        context 'when :raw option is' do
          context true do
            it 'returns the original body' do
              options = {
                  raw: true,
                  url: url_with_query,
                  http_method: :other,
                  body: 'stuff here #$^#46 %H# '
              }
              described_class.new( options ).effective_body.should == options[:body]
            end
          end

          context false do
            it 'escapes and returns the original body' do
              options = {
                  raw: false,
                  url: url_with_query,
                  http_method: :other,
                  body: 'stuff here #$^#46 %H# '
              }
              described_class.new( options ).effective_body.should ==
                  'stuff+here+%23%24%5E%2346+%25H%23+'
            end
          end

          context 'default' do
            it 'escapes and returns the original body' do
              options = {
                  url: url_with_query,
                  http_method: :other,
                  body: 'stuff here #$^#46 %H# '
              }
              described_class.new( options ).effective_body.should ==
                  'stuff+here+%23%24%5E%2346+%25H%23+'
            end
          end
        end

      end
    end
  end

  describe '#on_complete' do
    it 'adds a callback block to be passed the response' do
      request = described_class.new( url: url )

      passed_response = nil
      request.on_complete { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( url: url )
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new( url: url )

      passed_responses = []

      2.times do
        request.on_complete { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new( url: url )
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#on_success' do
    it 'adds a callback block to be called on a successful request' do
      request = described_class.new( url: url )

      passed_response = nil
      request.on_success { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( url: url, code: 200 )
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new( url: url )

      passed_responses = []

      2.times do
        request.on_success { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new( url: url, code: 200 )
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#on_failure' do
    it 'adds a callback block to be called on a failed request' do
      request = described_class.new( url: url )

      passed_response = nil
      request.on_failure { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( url: url, code: 0 )
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new( url: url )

      passed_responses = []

      2.times do
        request.on_failure { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new( url: url, code: 0 )
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#handle_response' do
    it 'assigns self as the #request attribute of the response' do
      request = described_class.new( url: url )

      passed_response = nil
      request.on_complete { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( url: url )
      request.handle_response( response )

      passed_response.request.should == request
    end

    context 'when a response is successful' do
      let(:response) { Raptor::Protocol::HTTP::Response.new( url: url, code: 200 ) }

      it 'calls #on_complete callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'calls #on_success callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_failure callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
    end
    context 'when a request fails' do
      let(:response) { Raptor::Protocol::HTTP::Response.new( url: url, code: 0 ) }

      it 'calls #on_complete callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_success callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
      it 'calls #on_failure callbacks' do
        request = described_class.new( url: url )

        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
    end
  end

  describe '#to_s' do
    it 'includes a Host header' do
      described_class.new( url: url ).to_s.should ==
          "GET / HTTP/1.1\r\n" +
              "Host: #{parsed_url.host}:#{parsed_url.port}\r\n\r\n"
    end

    context 'when the request method is' do
      context 'GET' do
        context 'when no parameters have been provided as options' do
          it 'uses the original URL' do
            r = described_class.new( url: url_with_query, http_method: :get )
            r.to_s.lines.first.should == "GET /?id=1&stuff=blah HTTP/1.1\r\n"
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
        context 'when no parameters have been provided as options' do
          it 'uses the original body' do
            options = {
                url: url_with_query,
                http_method: :post,
                body: 'stuff=1&blah=test'
            }
            described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
                options[:body]
          end
        end
        context 'when there are parameters as options' do
          let(:parameters) { { 'id $#^3 4q%$#' => '2 dfgr ', 'stuff' => 'blah' } }

          context 'and there is no body configured' do
            it 'uses the escaped option parameters' do
              options = {
                  url: url_with_query,
                  http_method: :post,
                  parameters: parameters
              }
              described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
                  "id+%24%23%5E3+4q%25%24%23=2+dfgr+&stuff=blah"
            end
          end
          context 'and there is a body' do
            it 'uses the body parameters merged with the options parameters' do
              options = {
                  url: url_with_query,
                  http_method: :post,
                  body: 'stuff 4354%$43=$#535!35VWE g4 %yt5&stuff=1',
                  parameters: parameters
              }
              described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
                  "stuff+4354%25%2443=%24%23535%2135VWE+g4+%25yt5&stuff=blah&id+%24%23%5E3+4q%25%24%23=2+dfgr+"
            end
          end
        end
      end

      context 'other' do
        it 'returns the original body' do
          options = {
              url: url_with_query,
              http_method: :other,
              body: 'stuff'
          }
          described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
              options[:body]
        end

        it 'escapes the original body' do
          options = {
              url: url_with_query,
              http_method: :other,
              body: 'stuff here #$^#46 %H# '
          }
          described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
              'stuff+here+%23%24%5E%2346+%25H%23+'
        end

        it 'returns the original URL' do
          options = {
              url: url_with_query,
              http_method: :other
          }
          described_class.new( options ).to_s.lines.first.should ==
              "OTHER /?id=1&stuff=blah HTTP/1.1\r\n"
        end
      end
    end

    context 'when headers' do
      context 'have been provided' do
        it 'escapes and includes them in the request' do
          options = {
              url:     url,
              headers: {
                  'X-Stuff' => "blah"
              }
          }
          described_class.new( options ).to_s.should ==
              "GET / HTTP/1.1\r\n" +
                "Host: #{parsed_url.host}:#{parsed_url.port}\r\n" +
                "X-Stuff: blah\r\n\r\n"
        end
      end
    end

    context 'when an HTTP method' do
      context 'has been provided' do
        it 'includes it the request' do
          options = {
              url:         url,
              http_method: :stuff
          }
          described_class.new( options ).to_s.lines.first.should == "STUFF / HTTP/1.1\r\n"
        end
      end
      context 'has not been provided' do
        it 'defaults to GET' do
          described_class.new( url: url ).to_s.lines.first.should == "GET / HTTP/1.1\r\n"
        end
      end
    end

    context 'when an HTTP version' do
      context 'has been provided' do
        it 'includes it the request' do
          options = {
              url:     url,
              version: '2'
          }
          described_class.new( options ).to_s.lines.first.should == "GET / HTTP/2\r\n"
        end
      end

      context 'has not been provided' do
        it 'defaults to 1.1' do
          described_class.new( url: url ).to_s.lines.first.should == "GET / HTTP/1.1\r\n"
        end
      end
    end

    context 'when there is a body' do
      it 'encodes it' do
        options = {
            url:  url,
            body: "fds g45\#$ 6@ %y @^2\r\n"
        }
        described_class.new( options ).to_s.split( /[\n\r]+/ ).last.should ==
                "fds+g45%23%24+6%40+%25y+%40%5E2%0D%0A"
      end
      it 'sets the Content-Length header' do
        options = {
            url:  url,
            body: "fds g45\#$ 6@ %y @^2\r\n"
        }
        described_class.new( options ).to_s.should ==
            "GET / HTTP/1.1\r\n" +
                "Host: #{parsed_url.host}:#{parsed_url.port}\r\n" +
                "Content-Length: 37\r\n\r\n" +
                "fds+g45%23%24+6%40+%25y+%40%5E2%0D%0A"
      end
    end

  end

end
