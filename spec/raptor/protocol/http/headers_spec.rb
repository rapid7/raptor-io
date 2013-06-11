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

  describe '#delete' do
    it 'deleted a header field' do
      h = described_class.new( 'x-my-field' => 'stuff' )
      h.delete( 'X-My-Field' ).should == 'stuff'
    end
  end

  describe '#include?' do
    context 'when the field is included' do
      it 'returns true' do
        h = described_class.new( 'X-My-Field' => 'stuff' )
        h.include?( 'x-my-field' ).should be_true
      end
    end
    context 'when the field is not included' do
      it 'returns false' do
        described_class.new.include?( 'x-my-field' ).should be_false
      end
    end
  end

  describe '.parse' do
    context 'when passed an empty string' do
      it 'returns empty Headers' do
        described_class.parse( '' ).should be_empty
      end
    end

    it 'supports CRLF terminators' do
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

    it 'supports CR terminators' do
      headers_string = "content-Type: text/html;charset=utf-8\n" +
          "Content-length: 431\n\n"

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
