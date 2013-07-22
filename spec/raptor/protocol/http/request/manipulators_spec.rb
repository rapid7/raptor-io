require 'spec_helper'

describe Raptor::Protocol::HTTP::Request::Manipulators do
  before( :each ) do
    described_class.reset
    described_class.library = manipulator_fixtures_path
  end

  it 'is Enumerable' do
    described_class.should be_kind_of Enumerable
  end

  describe '.class_to_name' do
    it 'returns the name of a loaded manipulator based on its class' do
      described_class.load_all
      described_class.class_to_name( Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli ).should ==
          'niccolo_machiavelli'
    end
  end

  describe '.process' do
    let(:client) do
      Raptor::Protocol::HTTP::Client.new(switch_board:Raptor::Socket::SwitchBoard.new)
    end
    it 'processes the given request and client with the given manipulator' do
      request = Raptor::Protocol::HTTP::Request.new( url: 'http://test/' )
      options = { stuff: 1 }

      datastore = client.datastore['niccolo_machiavelli']
      datastore['stuff'] = 'blah'

      described_class.process( :niccolo_machiavelli, client, request, options ).should ==
          [client, request, options, datastore]
    end

    context 'when given a non-existent manipulator' do
      it 'raises LoadError' do
        request = Raptor::Protocol::HTTP::Request.new( url: 'http://test/' )

        expect do
          described_class.process( :huaa!, client, request )
        end.to raise_error LoadError
      end
    end
  end

  describe '.validate_options' do
    context 'when the options are invalid' do
      it 'returns a Hash with errors' do
        described_class.validate_options(
            :options_validator,
            { mandatory_string: 12 },
            nil
        ).should eq({
            mandatory_string: 'Must be string.'
        })
      end
    end

    context 'when the options are valid' do
      it 'returns an empty Hash' do
        described_class.validate_options(
            :options_validator,
            { mandatory_string: 'Stuff' },
            nil
        ).should be_empty
      end
    end
  end

  describe '.validate_batch_options' do
    context 'when the options are invalid' do
      it 'returns a Hash with errors' do
        described_class.validate_batch_options(
            { options_validator: { mandatory_string: 12 } },
            nil
        ).should eq({
          options_validator: { mandatory_string: 'Must be string.' }
        })
      end
    end

    context 'when the options are valid' do
      it 'returns an empty Hash' do
        described_class.validate_batch_options(
            { options_validator: { mandatory_string: 'Stuff' } },
            nil
        ).should be_empty
      end
    end
  end

  describe '.library' do
    it 'returns the directory of the manipulators\' library' do
      File.directory?( described_class.library ).should be_true
    end
  end

  describe '.library=' do
    it 'sets the manipulators\' library directory' do
      described_class.library = '/tmp/'
      File.directory?( described_class.library ).should be_true
    end
  end

  describe '.paths' do
    it 'returns paths of all manipulators' do
      described_class.paths.each do |path|
        path.should start_with described_class.library
        File.exist?( path ).should be_true
      end
    end
  end

  describe '.exist?' do
    context 'when a manipulator exists' do
      it 'returns true' do
        described_class.exist?( 'niccolo_machiavelli' ).should be_true
      end
    end

    context 'when a manipulator does not exist' do
      it 'returns false' do
        described_class.exist?( 'stuffer_stufferson' ).should be_false
      end
    end
  end

  describe '.available' do
    it 'returns the names of all available manipulators' do
      described_class.available.sort.should eq [ 'niccolo_machiavelli', 'manifoolators/fooer', 'options_validator' ].sort
    end
  end

  describe '.load' do
    it 'loads a manipulator by filename' do
      described_class.load( :niccolo_machiavelli )
      described_class.loaded['niccolo_machiavelli'].should ==
          Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli
    end
    it 'returns the loaded manipulator' do
      described_class.load( :niccolo_machiavelli ).should ==
          Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli
    end

    context 'when given a non-existent manipulator' do
      it 'raises LoadError' do
        expect{ described_class.load( :huaa! ) }.to raise_error LoadError
      end
    end
  end

  describe '.load_all' do
    it 'loads all manipulators' do
      described_class.load_all
      described_class.loaded['niccolo_machiavelli'].should ==
          Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli
    end
    it 'returns the loaded manipulators' do
      described_class.load_all.should eq ({
        'manifoolators/fooer' => Raptor::Protocol::HTTP::Request::Manipulators::Manifoolators::Fooer,
        'niccolo_machiavelli' => Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli,
        'options_validator' => Raptor::Protocol::HTTP::Request::Manipulators::OptionsValidator
      })
    end
  end

  describe '.unload' do
    it 'unload a manipulator' do
      described_class.load( :niccolo_machiavelli )
      described_class.unload( :niccolo_machiavelli )
      described_class.loaded.should_not include :niccolo_machiavelli

      expect do
        Raptor::Protocol::HTTP::Request::Manipulators::NiccoloMachiavelli
      end.to raise_error NameError
    end
  end

  describe '.unload_all' do
    it 'unloads all manipulators' do
      described_class.load_all
      described_class.constants.size.should >= 1

      described_class.unload_all
      described_class.loaded.should be_empty
      described_class.constants.should be_empty
    end
  end

  describe '.each' do
    it 'returns each loaded manipulator' do
      described_class.load_all
      described_class.loaded.should be_any

      described_class.each do |name, klass|
        described_class.loaded[name].should == klass
      end
    end
  end

end
