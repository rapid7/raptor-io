require 'spec_helper'

describe Raptor::Protocol::HTTP::Response do
  it_should_behave_like 'Raptor::Protocol::HTTP::Message'

  let(:url) { 'http://test.com' }

  let(:response) do
    "HTTP/1.1 404 Not Found\r\n" +
"Content-Type: text/html;charset=utf-8\r\n" +
"Content-Length: 431\r\n\r\n" +
"<!DOCTYPE html>\n" +
"More stuff\n"
  end

  describe '#code' do
    it 'returns the HTTP status code' do
      described_class.new( url: url, code: 200 ).code.should == 200
    end

    it 'defaults to 0' do
      described_class.new( url: url ).code.should == 0
    end
  end

  describe '#request' do
    it 'returns the assigned request' do
      r = Raptor::Protocol::HTTP::Request.new( url: url )
      described_class.new( url: url, request: r ).request.should == r
    end
  end

  describe '.parse' do
    it 'parses an HTTP response string into a Response object' do
      r = described_class.parse( response )
      r.version.should == '1.1'
      r.code.should == 404
      r.message.should == 'Not Found'
      r.body.should == "<!DOCTYPE html>\nMore stuff\n"
      r.headers.should == {
          'Content-Type'   => 'text/html;charset=utf-8',
          'Content-Length' => '431'
      }
      r.to_s.should == response
    end

    context 'when passed an empty string' do
      it 'returns an empty response' do
        r = described_class.parse( '' )
        r.version.should == '1.1'
        r.code.should == 0
        r.message.should be_nil
        r.body.should be_nil
        r.headers.should == {}
      end
    end
  end

  describe '#to_s' do
    it 'returns a String representation of the response' do
      r = described_class.new(
        version: '1.1',
        code:         404,
        message:      'Not Found',
        body:         "<!DOCTYPE html>\nMore stuff\n",
        headers:      {
            'Content-Type'   => 'text/html;charset=utf-8',
            'Content-Length' => '431'
        }
      )

      r.to_s.should == response
    end
  end
end
