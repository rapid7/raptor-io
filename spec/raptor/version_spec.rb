require_relative '../spec_helper'

describe Raptor::VERSION do
  it 'holds the version number of the library' do
    splits = Raptor::VERSION.to_s.split( '.' )

    splits.should be_any
    splits.each { |number| number.should match /\d+/ }
  end
end
