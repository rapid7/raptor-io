require 'spec_helper'

describe "RaptorIO::VERSION" do
  it 'holds the version number of the library' do
    splits = RaptorIO::VERSION.to_s.split( '.' )

    splits.should be_any
    splits.each { |number| number.should match /\d+/ }
  end
end
