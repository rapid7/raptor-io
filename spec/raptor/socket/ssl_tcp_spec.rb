
require 'spec_helper'

require 'raptor/socket'
require 'raptor/socket/ssl_tcp'

describe Raptor::Socket::SSLTCP do
  subject { described_class.new(io, opts) }
  let(:opts) do
    {
      :ssl_version => :TLSv1,
      :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
    }
  end
  let(:io) { io = StringIO.new }

  it { should respond_to :ssl_client_connect }
  it { should respond_to :ssl_context }
  it { should respond_to :ssl_version }
  it { should respond_to :ssl_verify_mode }

  it_behaves_like "a client socket"

  context "with ssl server" do
    subject { described_class.new(io, opts) }
    let(:opts) do
      {
        :ssl_version => :TLSv1,
        :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
      }
    end
    include_context "with ssl server"
    let(:io) { client_sock }

    let(:data) { "wheeee!!".force_encoding("binary") }

    describe "#read" do
      it "should return what the server wrote" do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write(data)
          select([ssl_client], nil, nil, 0.1)
          ssl_client.read(data.length).should eql(data)
        end
      end
    end

  end
end

