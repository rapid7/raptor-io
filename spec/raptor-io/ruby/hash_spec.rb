require 'spec_helper'

describe Hash do
  describe '#stringify' do
    it 'returns a Hash with keys and values recursively converted to strings' do
      {
          test:         'blah',
          another_hash: {
              stuff: 'test'
          }
      }.stringify.should == {
          'test'         => 'blah',
          'another_hash' => {
              'stuff' => 'test'
          }
      }

    end
  end
end
