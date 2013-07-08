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

  let(:client) { Raptor::Protocol::HTTP::Client.new }

  it 'provides Basic authentication' do
    opts = {
        mode: :sync, manipulators: {
            'authenticator' =>
                {
                    response: client.get( @basic_url, mode: :sync ),
                    username: 'admin',
                    password: 'secret'
                }
        }
    }

    2.times do
      client.get( @basic_url, opts ).code.should == 200
    end
  end

  it 'provides Digest authentication' do
    opts = {
        mode: :sync, manipulators: {
            'authenticator' =>
                {
                    response: client.get( @digest_url, mode: :sync ),
                    username: 'admin',
                    password: 'secret'
                }
        }
    }

    2.times do
      client.get( @digest_url, opts ).code.should == 200
    end
  end
end

