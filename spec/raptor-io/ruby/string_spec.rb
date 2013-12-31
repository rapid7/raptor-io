require 'spec_helper'

describe String do

  describe '#binary?' do
    context 'when the content is' do
      context 'binary' do
        it 'returns true' do
          "\ff\ff\ff".binary?.should be_true
        end
      end
      context 'text' do
        it 'returns false' do
          'test'.binary?.should be_false
        end
      end
    end
  end

end
