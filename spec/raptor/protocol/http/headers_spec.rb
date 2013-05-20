require 'spec_helper'

describe Raptor::Protocol::HTTP::Headers do

  describe '#to_s' do
    it 'formats headers for HTTP transmission' do
      options = {
        'x-morE-stUfF' => 'blah'
      }
      described_class.new( options ).to_s.should ==
              "X-More-Stuff: blah"
    end
  end

  describe '.parse' do
    context 'when passed an empty string' do
      it 'returns empty Headers' do
        described_class.parse( '' ).should be_empty
      end
    end

    it 'parses an HTTP headers string' do
      headers_string = "content-Type: text/html;charset=utf-8\r\n" +
        "Content-length: 431\r\n\r\n"

      headers = described_class.parse( headers_string )
      headers.should ==
          {
              'Content-Type'      => 'text/html;charset=utf-8',
              'Content-Length'    => '431'
          }
      headers.class.should == described_class
    end
  end

end
