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
        switch_board: Raptor::Socket::SwitchBoard.new,
        manipulators: {
            'authenticator' =>
                {
                    username: 'admin',
                    password: 'secret'
                }
        }
    )
  end

  context 'when authentication is of type' do
    context 'Basic' do
      it 'provides Basic authentication' do
        opts = { mode: :sync }
        2.times do
          client.get( @basic_url, opts ).code.should == 200
        end
      end
    end

    context 'Digest' do
      it 'provides Digest authentication' do
        opts = { mode: :sync }

        2.times do
          client.get( @digest_url, opts ).code.should == 200
        end
      end

      it 'doesn\'t run any queued request until the auth finishes' do
        cnt = 0

        50.times do |i|
          client.get( @digest_url ) do |response|
            response.code.should == 200
            cnt += 1
          end
        end

        client.run
        client.datastore['authenticator'][:tries].should == 1
        cnt.should == 51
      end
    end
  end

end

