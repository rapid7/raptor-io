require 'spec_helper'
require 'raptor-io/socket'

describe 'RaptorIO::Protocol::HTTP::Request::Manipulators::Authenticators::Digest' do

  let(:url) { "http://127.0.0.1/digest_spec" }

  let(:manipulators) { RaptorIO::Protocol::HTTP::Request::Manipulators }

  before(:each) do
    RaptorIO::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) do
    sb = RaptorIO::Socket::SwitchBoard.new
    RaptorIO::Protocol::HTTP::Client.new(switch_board: sb)
  end

  let(:algorithm) { "MD5" }
  let(:response_401) do
    RaptorIO::Protocol::HTTP::Response.parse(
      [
        "HTTP/1.1 401 Unauthorized",
        "Content-Type: text/plain",
        "Content-Length: 0",
        "WWW-Authenticate: Digest" +
        [
          %Q|realm="Protected Area"|,
          %Q|algorithm="#{algorithm}"|,
          %Q|nonce="MTM3MzI5OTYxNiAxYzk2ZDM4OWY1MTY2ZGM3ODllNGQ2N2RjZDIyYzk1ZA=="|,
          %Q|opaque="610a2ee688cda9e724885e23cd2cfdee"|,
          %Q|qop="auth"|,
        ].join(", "),
        "Connection: keep-alive",
        "Server: thin 1.5.1 codename Straight Razor",
        "\r\n"
      ].join("\r\n")
    )
  end

  context 'when authenticating to a real server' do
    before :all do
      WebServers.start :digest
      @url = WebServers.url_for( :digest )
    end
    let(:url) { @url }

    context 'with the wrong password' do
      it 'fails authentication' do
        opts = {
          mode: :sync,
          manipulators: {
            'authenticators/digest' =>
            {
              response: client.get( url, mode: :sync ),
              username: 'admin',
              password: 'wrong'
            }
          }
        }

        2.times do
          client.get( url, opts ).code.should == 401
        end
      end
    end

    context 'with the correct password' do
      it 'authenticates successfully' do
        opts = {
          mode: :sync,
          manipulators: {
            'authenticators/digest' =>
            {
              response: client.get( url, mode: :sync ),
              username: 'admin',
              password: 'secret'
            }
          }
        }

        2.times do
          client.get( url, opts ).code.should == 200
        end
      end
    end
  end

  context 'with known hashing algorithms' do
    %w(MD5 SHA1 SHA2 SHA256 SHA384 SHA512 RMD160).each do |algo|
      let(:algorithm) { algo }
      it "supports #{algo}" do
        expect {
          manipulators.process(
            'authenticators/digest',
            client,
            RaptorIO::Protocol::HTTP::Request.new( url: url ),
            {
              response: response_401,
              username: 'admin',
              password: 'secret'
            }
          )
        }.not_to raise_error
      end
    end
  end

  context 'with unknown algorithm' do
    let(:algorithm) { 'stuff' }
    it 'raises error on unknown algorithm' do
      expect {
        manipulators.process(
          'authenticators/digest',
          client,
          RaptorIO::Protocol::HTTP::Request.new( url: url ),
          {
            response: response_401,
            username: 'admin',
            password: 'secret'
          }
        )
      }.to raise_error RaptorIO::Protocol::HTTP::Error
    end
  end
end

