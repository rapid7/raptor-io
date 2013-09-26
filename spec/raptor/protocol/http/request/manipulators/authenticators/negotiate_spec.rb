require 'spec_helper'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::Authenticators::Negotiate' do
  before :all do
    WebServers.start :basic
    @url = "http://#{ENV['IIS']}/negotiate/"
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) { Raptor::Protocol::HTTP::Client.new }

  it 'provides Negotiate authentication' do
    pending if !ENV['IIS']

    opts = {
        mode: :sync, manipulators: {
            'authenticators/negotiate' =>
                {
                    username: 'msfadmin',
                    password: 'msfadmin'
                }
        }
    }

    2.times do
      client.get( @url, opts ).code.should == 200
    end
  end

  context 'on wrong credentials' do
    it 'returns a 401' do
      pending if !ENV['IIS']

      opts = {
          mode: :sync, manipulators: {
              'authenticators/negotiate' =>
                  {
                      username: 'blah',
                      password: 'blah'
                  }
          }
      }

      2.times do
        client.get( @url, opts ).code.should == 401
      end
    end
  end
end
