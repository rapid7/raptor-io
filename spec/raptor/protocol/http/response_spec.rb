require 'spec_helper'

describe Raptor::Protocol::HTTP::Response do
  it_should_behave_like 'Raptor::Protocol::HTTP::PDU'

  let(:url) { 'http://test.com' }

  describe '#code' do
    it 'returns the HTTP status code' do
      described_class.new( url: url, code: 200 ).code.should == 200
    end

    it 'defaults to 0' do
      described_class.new( url: url ).code.should == 0
    end
  end

  describe '#request' do
    it 'returns the assigned request' do
      r = Raptor::Protocol::HTTP::Request.new( url: url )
      described_class.new( url: url, request: r ).request.should == r
    end
  end

  describe '#to_s' do
    it 'returns a String representation of the response'
  end
end
