require 'spec_helper'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::Authenticator' do
  before :all do
    WebServers.start :basic
    @basic_url = WebServers.url_for( :basic )

    WebServers.start :digest
    @digest_url = WebServers.url_for( :digest )
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) do
    Raptor::Protocol::HTTP::Client.new(
        manipulators: {
            'authenticator' =>
                {
                    username: 'admin',
                    password: 'secret'
                }
        }
    )
  end

  it 'provides Basic authentication' do
    opts = { mode: :sync }
    2.times do
      client.get( @basic_url, opts ).code.should == 200
    end
  end

  it 'provides Digest authentication' do
    opts = { mode: :sync }

    2.times do
      client.get( @digest_url, opts ).code.should == 200
    end
  end
end

