require 'spec_helper'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::RedirectFollower' do
  before :all do
    WebServers.start :redirect_follower
    @url = WebServers.url_for( :redirect_follower )
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) do
    Raptor::Protocol::HTTP::Client.new(
        manipulators: {
            redirect_follower: { max: 6 }
        }
    )
  end

  it 'sets the limit on how many stacked redirections to follow' do
    response = client.get( "#{@url}/10", mode: :sync )
    response.redirections.size.should == 6
    response.headers['Location'].should == "#{@url}/3"
  end

  it 'defaults to 5' do
    client = Raptor::Protocol::HTTP::Client.new(
        manipulators: {
            redirect_follower:   {}
        }
    )

    response = client.get( "#{@url}/10", mode: :sync )
    response.redirections.size.should == 5
    response.headers['Location'].should == "#{@url}/4"
  end

end

