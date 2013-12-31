require 'spec_helper'
require 'raptor-io/socket'

describe RaptorIO::Socket::TCP::SSL do
  let(:opts) do
    {
        ssl_version:     :TLSv1,
        ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  end

  #include_context 'with ssl server'

  #it_behaves_like "a client socket"

end


