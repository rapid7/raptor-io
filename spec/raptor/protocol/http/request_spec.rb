require_relative '../../../spec_helper'
require 'ostruct'

describe Raptor::Protocol::HTTP::Request do
  it_should_behave_like 'Raptor::Protocol::HTTP::PDU'

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

  describe '#on_complete' do
    it 'adds a callback block to be passed the response' do
      request = described_class.new

      passed_response = nil
      request.on_complete { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new

      passed_responses = []

      2.times do
        request.on_complete { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#on_success' do
    it 'adds a callback block to be called on a successful request' do
      request = described_class.new

      passed_response = nil
      request.on_success { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( code: 200 )
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new

      passed_responses = []

      2.times do
        request.on_success { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new( code: 200 )
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#on_failure' do
    it 'adds a callback block to be called on a failed request' do
      request = described_class.new

      passed_response = nil
      request.on_failure { |res| passed_response = res }

      response = Raptor::Protocol::HTTP::Response.new( code: 0 )
      request.handle_response( response )

      passed_response.should == response
    end

    it 'can add multiple callbacks' do
      request = described_class.new

      passed_responses = []

      2.times do
        request.on_failure { |res| passed_responses << res }
      end

      response = Raptor::Protocol::HTTP::Response.new( code: 0 )
      request.handle_response( response )

      passed_responses.size.should == 2
      passed_responses.uniq.size.should == 1
      passed_responses.uniq.first.should == response
    end
  end

  describe '#handle_response' do
    context 'when a response is successful' do
      let(:response) { Raptor::Protocol::HTTP::Response.new( code: 200 ) }

      it 'calls #on_complete callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'calls #on_success callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_failure callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
    end
    context 'when a request fails' do
      let(:response) { Raptor::Protocol::HTTP::Response.new( code: 0 ) }

      it 'calls #on_complete callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_complete { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
      it 'does not call #on_success callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_success { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should be_nil
      end
      it 'calls #on_failure callbacks' do
        request = described_class.new

        passed_response = nil
        request.on_failure { |res| passed_response = res }
        request.handle_response( response )

        passed_response.should == response
      end
    end
  end

  describe '#to_s' do
    it 'returns a String representation of the request'
  end
end
