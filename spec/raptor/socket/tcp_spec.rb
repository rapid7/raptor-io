
require 'spec_helper'

require 'raptor/socket'

describe Raptor::Socket::TCP do
  subject do
    described_class.new(io, opts)
  end
  let(:io) { io = StringIO.new }
  let(:opts) { {} }

  it_behaves_like "a client socket"

  it { should respond_to(:ssl_client_connect) }

  context "with ssl server" do
    include_context "with ssl server"
    let(:io) { client_sock }
    let(:opts) do
      {
        :ssl_version => :TLSv1,
        :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
      }
    end

    let(:data) { "wheeee!!\n".force_encoding("binary") }

    describe "#readpartial" do
      it "should return what the server wrote" do
        with_ssl_sockets do |ssl_client, ssl_peer|
          ssl_peer.write(data)
          select([ssl_client], nil, nil, 0.1)
          ssl_client.readpartial(data.length).should eql(data)
        end
      end
    end

  end

end
