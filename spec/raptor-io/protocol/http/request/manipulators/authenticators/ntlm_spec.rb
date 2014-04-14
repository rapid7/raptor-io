require 'spec_helper'

describe 'RaptorIO::Protocol::HTTP::Request::Manipulators::Authenticators::NTLM' do
  before :all do
    WebServers.start :default
    @url = "http://#{ENV['IIS']}/ntlm/"
  end

  before( :each ) do
    RaptorIO::Protocol::HTTP::Request::Manipulators.reset
  end

  let(:client) { RaptorIO::Protocol::HTTP::Client.new }

  it 'provides NTLM authentication' do
    pending if !ENV['IIS']

    response = client.get( @url, mode: :sync )
    response.code.should == 401

    opts = {
        mode: :sync, manipulators: {
            'authenticators/ntlm' =>
                {
                    username: 'msfadmin',
                    password: 'msfadmin',
                    response: response
                }
        }
    }

    2.times do
      client.get( @url, opts ).code.should == 200
    end

  end
end
