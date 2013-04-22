require_relative '../../../spec_helper'

describe Raptor::Protocol::HTTP::Response do
  it_should_behave_like 'Raptor::Protocol::HTTP::PDU'

  describe '#request' do
    it 'returns the assigned request' do
      r = Raptor::Protocol::HTTP::Request.new
      described_class.new( request: r ).request.should == r
    end
  end

  describe '#to_s' do
    it 'returns a String representation of the response'
  end
end
