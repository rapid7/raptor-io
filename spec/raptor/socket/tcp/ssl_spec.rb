require 'spec_helper'
require 'raptor/socket'

describe Raptor::Socket::TCP::SSL do
  include_context 'with ssl server'

  let(:io) { unconnected_client_sock }
  let(:opts) do
    {
        version:     :TLSv1,
        verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  end
  let(:ssl_client) { subject }

  subject { described_class.new( io, opts ) }

  it { should respond_to :connect }
  it { should respond_to :context }
  it { should respond_to :version }
  it { should respond_to :verify_mode }
  it { should respond_to :getpeername }
  it { should respond_to :accept_nonblock }

  #it_behaves_like "a client socket"

  describe '#gets' do
    let(:io) { client_sock }
    let(:data) { "0\n1\n2\n3\n4\n".force_encoding( 'binary' ) }
    let(:data_io) { StringIO.new( data ) }

    it 'returns each line from the buffer' do
      with_ssl_sockets do |ssl_client, ssl_peer|
        ssl_peer.write(data)

        5.times do |i|
          select([ssl_client], nil, nil, 0.1)

          ssl_client.gets.should == data_io.gets
        end
      end
    end

    context 'when passed as an argument' do
      describe Integer do
        it 'reads and returns that amount of data from the buffer' do
          with_ssl_sockets do |ssl_client, ssl_peer|
            ssl_peer.write(data)

            5.times do |i|
              select([ssl_client], nil, nil, 0.1)

              ssl_client.gets( 1 ).should == data_io.gets( 1 )
            end
          end
        end
      end

      describe String do
        let(:data) { '0--1--2--3--4--'.force_encoding( 'binary' ) }
        let(:data_io) { StringIO.new( data ) }

        it 'uses it a newline separator' do
          with_ssl_sockets do |ssl_client, ssl_peer|
            ssl_peer.write(data)

            5.times do |i|
              select([ssl_client], nil, nil, 0.1)

              ssl_client.gets( '--' ).should == data_io.gets( '--' )
            end
          end
        end
      end

      describe 'String and Integer' do
        let(:data) { '000--1111--2222--3333--4444--'.force_encoding( 'binary' ) }
        let(:data_io) { StringIO.new( data ) }

        it 'uses the String as a newline separator and the Integer as a max-size' do
          with_ssl_sockets do |ssl_client, ssl_peer|
            ssl_peer.write(data)

            5.times do |i|
              select([ssl_client], nil, nil, 0.1)

              ssl_client.gets( '--', 2 ).should == data_io.gets( '--', 2 )
            end
          end
        end
      end
    end
  end

  context 'with ssl server' do
    let(:io) { client_sock }
    let(:data) { 'wheeee!!'.force_encoding( 'binary' ) }

    describe '#read' do
      it 'should return what the server wrote' do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write( data )
          select( [ssl_client] , nil, nil, 0.1 )

          ssl_client.read( data.length ).should eql( data )
        end
      end
    end
  end
end

