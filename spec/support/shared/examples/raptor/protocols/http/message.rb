shared_examples_for 'RaptorIO::Protocol::HTTP::Message' do

  let(:url) { 'http://test.com' }

  describe '#initialize' do
    it 'sets the instance attributes by the options' do
      options = {
          url:          url,
          version: '1.0',
          headers:      {
              'X-Stuff' => 'Blah'
          }
      }
      r = described_class.new( options )
      r.version.should == options[:version]
      r.headers.should == options[:headers]
    end
  end

  describe '#version' do
    it 'defaults to 1.1' do
      described_class.new( url: url ).version.should == '1.1'
    end
  end

  describe '#keep_alive?' do
    context 'when the protocol version is 1.1 or higher' do
      context 'and connection-token is set to \'close\'' do
        it 'returns false' do
          described_class.new( url: url,
                               version: '1.1',
                               headers: { 'connection' => 'close' }
          ).keep_alive?.should be_false
        end
      end

      it 'returns true' do
        described_class.new( url: url, version: '1.1' ).keep_alive?.should be_true
        described_class.new( url: url, version: '1.2' ).keep_alive?.should be_true
      end
    end

    context 'when the protocol version is lower than 1.1' do
      context 'and connection-token is set to \'keep-alive\'' do
        it 'returns false' do
          described_class.new( url: url,
                               version: '1.0',
                               headers: { 'connection' => 'keep-alive' }
          ).keep_alive?.should be_true
        end
      end

      it 'returns false' do
        described_class.new( url: url, version: '1.0' ).keep_alive?.should be_false
      end
    end
  end

  describe '#http_1_1?' do
    context 'when the protocol version is 1.1' do
      it 'returns true' do
        described_class.new( url: url, version: '1.1' ).http_1_1?.should be_true
      end
    end

    context 'when the protocol version is not 1.1' do
      it 'returns false' do
        described_class.new( url: url, version: '1.2' ).http_1_1?.should be_false
      end
    end
  end

  describe '#http_1_0?' do
    context 'when the protocol version is 1.0' do
      it 'returns true' do
        described_class.new( url: url, version: '1.0' ).http_1_0?.should be_true
      end
    end

    context 'when the protocol version is not 1.0' do
      it 'returns false' do
        described_class.new( url: url, version: '1.2' ).http_1_0?.should be_false
      end
    end
  end

  describe '#headers' do
    context 'when not configured' do
      it 'defaults to an empty Hash' do
        described_class.new( url: url ).headers.should == {}
      end
    end

    it 'returns the configured value' do
      headers = { 'Content-Type' => 'text/plain' }
      described_class.new( url: url, headers: headers ).headers.should == headers
    end
  end

  describe '#body' do
    it 'returns the configured body' do
      body = 'Stuff...'
      described_class.new( url: url, body: body ).body.should == body
    end
  end
end
