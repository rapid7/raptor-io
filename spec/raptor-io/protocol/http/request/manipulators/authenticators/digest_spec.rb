require 'spec_helper'
require 'raptor-io/socket'

describe 'RaptorIO::Protocol::HTTP::Request::Manipulators::Authenticators::Digest' do
  before :all do
    WebServers.start :digest
    @url = WebServers.url_for( :digest )
  end

  let( :manipulators ) { RaptorIO::Protocol::HTTP::Request::Manipulators }
  before( :each ) do
    RaptorIO::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) do
    sb = RaptorIO::Socket::SwitchBoard.new
    RaptorIO::Protocol::HTTP::Client.new(switch_board: sb)
  end

  def response( algo )
    RaptorIO::Protocol::HTTP::Response.parse "HTTP/1.1 401 Unauthorized
Content-Type: text/plain
Content-Length: 0
Www-Authenticate: Digest realm=\"Protected Area\", algorithm=\"#{algo}\", nonce=\"MTM3MzI5OTYxNiAxYzk2ZDM4OWY1MTY2ZGM3ODllNGQ2N2RjZDIyYzk1ZA==\", opaque=\"610a2ee688cda9e724885e23cd2cfdee\", qop=\"auth\"
Connection: keep-alive
Server: thin 1.5.1 codename Straight Razor\r\n\r\n"
  end

  it 'provides Digest authentication' do
    opts = {
        mode: :sync, manipulators: {
            'authenticators/digest' =>
                {
                    response: client.get( @url, mode: :sync ),
                    username: 'admin',
                    password: 'secret'
                }
        }
    }

    2.times do
      client.get( @url, opts ).code.should == 200
    end
  end

  %w(MD5 SHA1 SHA2 SHA256 SHA384 SHA512 RMD160).each do |algo|
    it "supports #{algo}" do
      manipulators.process(
          'authenticators/digest',
          client,
          RaptorIO::Protocol::HTTP::Request.new( url: @url ),
          {
              response: response( algo ),
              username: 'admin',
              password: 'secret'
          }
      )
    end
  end

  it 'raises error on unknown algorithm' do
    expect do
      manipulators.process(
          'authenticators/digest',
          client,
          RaptorIO::Protocol::HTTP::Request.new( url: @url ),
          {
              response: response( 'stuff' ),
              username: 'admin',
              password: 'secret'
          }
      )
    end.to raise_error RaptorIO::Protocol::HTTP::Error
  end
end

