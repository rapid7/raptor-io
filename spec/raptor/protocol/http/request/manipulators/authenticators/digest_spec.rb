require 'spec_helper'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::Authenticators::Digest' do
  before :all do
    WebServers.start :digest
    @url = WebServers.url_for( :digest )
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) { Raptor::Protocol::HTTP::Client.new }

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
end

