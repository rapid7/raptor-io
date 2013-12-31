require 'spec_helper'

require 'raptor-io/socket'

describe RaptorIO::Socket do
  subject { described_class.new(io) }
  let(:io) { StringIO.new }

  it "should not swallow errors in method_missing" do
    subject.should_not respond_to(:asdfjkl)
    expect {
      subject.asdfjkl
    }.to raise_error(NoMethodError)
  end
end

