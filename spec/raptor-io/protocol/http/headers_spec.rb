require 'spec_helper'

describe RaptorIO::Protocol::HTTP::Headers do

  describe '#to_s' do
    it 'supports multiple headers' do
      headers = described_class.new( 'X-Stuff' => %w(1 2 3) )
      headers.to_s.should == "X-Stuff: 1\r\nX-Stuff: 2\r\nX-Stuff: 3"
    end

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

  describe '#set_cookie' do
    context 'when there are no set-cookie fields' do
      it 'returns an empty array' do
        described_class.new.cookies.should == []
      end
    end

    it 'returns an array of set-cookie strings' do
      set_coookies = [
          'name=value; Expires=Wed, 09 Jun 2020 10:18:14 GMT',
          'name2=value2; Expires=Wed, 09 Jun 2021 10:18:14 GMT'
      ]

      described_class.new( 'Set-Cookie' => set_coookies ).set_cookie.should == set_coookies
    end
  end

  describe '#parsed_set_cookie' do
    context 'when there are no Set-cookie fields' do
      it 'returns an empty array' do
        described_class.new.parsed_set_cookie.should == []
      end
    end

    it 'returns an array of cookies as hashes' do
      described_class.new(
          'Set-Cookie' => [
              'name=value; Expires=Wed, 09 Jun 2020 10:18:14 GMT',
              'name2=value2; Expires=Wed, 09 Jun 2021 10:18:14 GMT'
          ]
      ).parsed_set_cookie.should == [
          {
              name:         'name',
              value:        'value',
              version:      0,
              port:         nil,
              discard:      nil,
              comment_url:  nil,
              expires:      Time.parse( '2020-06-09 13:18:14 +0300' ),
              max_age:      nil,
              comment:      nil,
              secure:       nil,
              path:         nil,
              domain:       nil
          },
          {
              name:         'name2',
              value:        'value2',
              version:      0,
              port:         nil,
              discard:      nil,
              comment_url:  nil,
              expires:      Time.parse( '2021-06-09 13:18:14 +0300' ),
              max_age:      nil,
              comment:      nil,
              secure:       nil,
              path:         nil,
              domain:       nil
          }
      ]
    end
  end

  describe '#cookies' do
    context 'when there is no Cookie fied' do
      it 'returns an empty array' do
        described_class.new.cookies.should == []
      end
    end

    it 'returns an array of cookies as hashes' do
      described_class.new(
          'Cookie' => 'cname=cvalue; c2name=c2value'
      ).cookies.should == [
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

  describe '.parse' do
    context 'when passed an empty string' do
      it 'returns empty Headers' do
        described_class.parse( '' ).should be_empty
      end
    end

    it 'supports multiple headers' do
      headers_string = "X-Stuff: 1\r\nX-Stuff: 2\r\n\r\n"

      headers = described_class.parse( headers_string )
      headers['x-stuff'].should == %w(1 2)
      headers.class.should == described_class
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
