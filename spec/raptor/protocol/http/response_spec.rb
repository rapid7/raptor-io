require 'spec_helper'

describe Raptor::Protocol::HTTP::Response do
  it_should_behave_like 'Raptor::Protocol::HTTP::Message'

  let(:url) { 'http://test.com' }

  let(:response) do
    "HTTP/1.1 404 Not Found\r\n" +
      "Content-Type: text/html;charset=utf-8\r\n" +
      "Content-Length: 431\r\n\r\n" +
      "<!DOCTYPE html>\n" +
      "More stuff\n".force_encoding( 'ASCII-8BIT')
  end

  let(:response_cr) do
    "HTTP/1.1 404 Not Found\n" +
      "Content-Type: text/html;charset=utf-8\n" +
      "Content-Length: 431\n\n" +
      "<!DOCTYPE html>\n" +
      "More stuff\n".force_encoding( 'ASCII-8BIT')
  end

  describe '#code' do
    it 'returns the HTTP status code' do
      described_class.new( url: url, code: 200 ).code.should == 200
    end

    it 'defaults to 0' do
      described_class.new( url: url ).code.should == 0
    end
  end

  describe '#body' do
    it 'returns the HTTP response body' do
      described_class.parse( response ).body.should == "<!DOCTYPE html>\nMore stuff\n"
    end

    it 'is forced to UTF8' do
      described_class.parse( response ).body.encoding.to_s.should == 'UTF-8'
    end
  end

  describe '#redirect?' do
    context 'when the code is in the 3xx family' do
      context 'and there is a Location in the headers' do
        it 'returns true' do
          300.upto( 399 ) do |code|
            described_class.new(
                url: url,
                code: code,
                headers: { 'Location' => url }
            ).redirect?.should be_true
          end
        end
      end
      context 'and there is no Location in the headers' do
        it 'returns false' do
          300.upto( 399 ) do |code|
            described_class.new(
                url: url,
                code: code
            ).redirect?.should be_false
          end
        end
      end
    end

    context 'when the code is not in the 3xx family' do
      it 'returns false' do
        described_class.new(
            url: url,
            code: 200
        ).redirect?.should be_false
      end

      context 'and there is a Location in the headers' do
        it 'returns true' do
          described_class.new(
              url: url,
              code: 200,
              headers: { 'Location' => url }
          ).redirect?.should be_false
        end
      end
    end
  end

  describe '#modified?' do
    context 'when the code is 304' do
      it 'returns false' do
        described_class.new( url: url, code: 304 ).modified?.should be_false
      end
    end
    context 'when the code is not 304' do
      it 'returns true' do
        described_class.new( url: url, code: 301 ).modified?.should be_true
      end
    end
  end

  describe '#request' do
    it 'returns the assigned request' do
      r = Raptor::Protocol::HTTP::Request.new( url: url )
      described_class.new( url: url, request: r ).request.should == r
    end
  end

  describe '.parse' do
    it 'supports CRLF terminators' do
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

    it 'supports CR terminators' do
      r = described_class.parse( response_cr )
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
