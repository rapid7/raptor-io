require_relative '../../../spec_helper'
require 'ostruct'

describe Raptor::Protocols::HTTP::Request do
  it_should_behave_like 'Raptor::Protocols::HTTP::PDU'

  describe '#initialize' do
    it 'sets the instance attributes by the options' do
      options = { method: :get, parameters: { 'test' => 'blah' } }
      described_class.new( options ).http_method.should == options[:method]
      described_class.new( options ).parameters.should == options[:parameters]
    end
    it 'uses the setter methods when configuring' do
      options = { method: 'gEt', parameters: { 'test' => 'blah' } }
      described_class.new( options ).http_method.should == :get
    end
  end

  describe '#http_method' do
    it 'defaults to :get' do
      described_class.new.http_method.should == :get
    end
  end

  describe '#http_method=' do
    it 'sets the HTTP method' do
      described_class.new.http_method.should == :get
    end
    it 'normalizes the HTTP method to a downcase symbol' do
      request = described_class.new
      request.http_method = 'GeT'
      request.http_method.should == :get
    end
  end

  describe '#parameters' do
    it 'defaults to an empty Hash' do
      described_class.new.parameters.should == {}
    end

    it 'recursively forces converts keys and values to strings' do
      with_symbols = {
          test:         'blah',
          another_hash: {
              stuff: 'test'
          }
      }
      with_strings = {
          'test'         => 'blah',
          'another_hash' => {
              'stuff' => 'test'
          }
      }

      request = described_class.new
      request.parameters = with_symbols
      request.parameters.should == with_strings
    end

  end

  describe '#to_s' do
    it 'returns a String representation of the request'
  end
end
