require 'spec_helper'

describe 'Raptor::Protocol::HTTP::Request::Manipulators::Authenticator' do
  before :all do
    WebServers.start :basic
    @basic_url = WebServers.url_for( :basic )

    WebServers.start :digest
    @digest_url = WebServers.url_for( :digest )

    @iis_address   = ENV['IIS']
    @ntlm_url      = "http://#{@iis_address}/ntlm/"
    @negotiate_url = "http://#{@iis_address}/negotiate/"
  end

  before( :each ) do
    Raptor::Protocol::HTTP::Request::Manipulators.reset
    Raptor::Protocol::HTTP::Client.reset
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
        cnt.should == 50
      end
    end

    context 'Negotiate' do
      let(:client) do
        Raptor::Protocol::HTTP::Client.new(
            manipulators: {
                'authenticator' =>
                    {
                        username: 'msfadmin',
                        password: 'msfadmin'
                    }
            }
        )
      end

      it 'provides Negotiate authentication' do
        pending if !ENV['IIS']

        opts = { mode: :sync }

        2.times do
          client.get( @negotiate_url, opts ).code.should == 200
        end
      end

      it 'doesn\'t run any queued request until the auth finishes' do
        pending if !ENV['IIS']

        cnt = 0

        50.times do |i|
          client.get( @negotiate_url ) do |response|
            response.code.should == 200
            cnt += 1
          end
        end

        client.run
        cnt.should == 50
      end

      context 'on wrong credentials' do
        it 'returns a 401' do
          pending if !ENV['IIS']

          opts = {
              mode: :sync, manipulators: {
                  'authenticator' =>
                      {
                          username: 'blah',
                          password: 'blah'
                      }
              }
          }

          2.times do
            client.get( @negotiate_url, opts ).code.should == 401
          end
        end
      end
    end

    context 'NTLM' do
      let(:client) do
        Raptor::Protocol::HTTP::Client.new(
            manipulators: {
                'authenticator' =>
                    {
                        username: 'msfadmin',
                        password: 'msfadmin'
                    }
            }
        )
      end

      it 'provides NTLM authentication' do
        pending if !ENV['IIS']

        opts = { mode: :sync }

        2.times do
          client.get( @ntlm_url, opts ).code.should == 200
        end
      end

      it 'doesn\'t run any queued request until the auth finishes' do
        pending if !ENV['IIS']

        cnt = 0

        50.times do |i|
          client.get( @ntlm_url ) do |response|
            response.code.should == 200
            cnt += 1
          end
        end

        client.run
        cnt.should == 50
      end

      context 'on wrong credentials' do
        it 'returns a 401' do
          pending if !ENV['IIS']

          opts = {
              mode: :sync, manipulators: {
                  'authenticator' =>
                      {
                          username: 'blah',
                          password: 'blah'
                      }
              }
          }

          2.times do
            client.get( @ntlm_url, opts ).code.should == 401
          end
        end
      end
    end

  end

end

