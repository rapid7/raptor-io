require 'spec_helper'

describe Raptor::Protocol::HTTP::Headers do

  describe '#to_s' do
    it 'formats headers for HTTP transmission' do
      options = {
        'X-Stuff !@$^54 n7' => "dsad3R$#% t@%Y1y165^U2 \r\n",
        'X-More-Stuff'      => 'blah'
      }
      described_class.new( options ).to_s.should ==
              "X-Stuff+%21%40%24%5E54+n7: dsad3R%24%23%25+t%40%25Y1y165%5EU2+%0D%0A\r\n" +
              "X-More-Stuff: blah"
    end
  end

  describe '.parse' do
    it 'parses an HTTP headers string' do
      headers_string = "Content-Type: text/html;charset=utf-8\r\n" +
        "X-Stuff+%21%40%24%5E54+n7: dsad3R%24%23%25+t%40%25Y1y165%5EU2+%0D%0A\r\n" +
        "Content-Length: 431\r\n\r\n"

      headers = described_class.parse( headers_string )
      headers.should ==
          {
              'X-Stuff !@$^54 n7' => "dsad3R$#% t@%Y1y165^U2 \r\n",
              'Content-Type'      => 'text/html;charset=utf-8',
              'Content-Length'    => '431'
          }
      headers.class.should == described_class
    end
  end

end
