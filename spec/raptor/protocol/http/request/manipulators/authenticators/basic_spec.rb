require 'spec_helper'
require 'raptor/socket'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::Authenticators::Basic' do
  before :all do
    WebServers.start :basic
    @url = WebServers.url_for( :basic )
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) { Raptor::Protocol::HTTP::Client.new(switch_board:Raptor::Socket::SwitchBoard.new) }

  it 'provides Basic authentication' do
    opts = {
        mode: :sync, manipulators: {
            'authenticators/basic' =>
                {
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

