shared_examples_for 'Raptor::Protocols::HTTP::PDU' do

  describe '#url' do
    it 'returns the configured value' do
      url = 'http://test.com'
      described_class.new( url: url ).url.should == url
    end
  end

  describe '#headers' do
    context 'when not configured' do
      it 'defaults to an empty Hash' do
        described_class.new.headers.should == {}
      end
    end

    it 'returns the configured value' do
      headers = { 'Content-Type' => 'text/plain' }
      described_class.new( headers: headers ).headers.should == headers
    end
  end

  describe '#body' do
    body = 'Stuff...'
    described_class.new( body: body ).body.should == body
  end
end
