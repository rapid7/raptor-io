module Raptor
module Protocol::HTTP

class Request

require_relative 'manipulator'

# Namespace holding all Request manipulators and providing some helper methods
# for management.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
module Manipulators

  class <<self
    include Enumerable

    # @return [String]  Directory of the manipulators' repository.
    attr_reader :library

    # @param  [String]  manipulator
    #   Manipulator to run -- will be loaded if needed.
    # @param  [HTTP::Client]  client
    #   Applicable client.
    # @param  [HTTP::Request]  request
    #   Request to process.
    # @param  [Hash]  options
    #   Manipulator options.
    def process( manipulator, client, request, options = {} )
      load( manipulator ).new( client, request, options ).run
    end

    # Performs batch validation of manipulator options.
    #
    # @param  [Hash{String=>Hash}]  manipulators
    #   Manipulators for keys and their options as values.
    # @param  [HTTP::Client]  client
    #   Applicable client.
    #
    # @return [Hash{String=>Hash}]
    #   Manipulators for keys and error hashes as values.
    #
    def validate_batch_options( manipulators, client )
      errors = {}
      manipulators.each do |manipulator, options|
        errors[manipulator] =
            validate_options( manipulator, options, client )
      end
      errors.reject { |_, errs| errs.empty? }
    end

    # Same as {.validate_batch_options} but raises exception on errors.
    def validate_batch_options!( manipulators, client )
      errors = validate_batch_options( manipulators, client )
      if errors.any?
        fail Request::Manipulator::Error::InvalidOptions, errors.to_s
      end
      nil
    end

    # @param  [String]  manipulator
    # @param  [Hash]  options Manipulator options.
    # @param  [HTTP::Client]  client  Applicable client.
    #
    # @return [Hash{Symbol=>Array<String>}]
    #   Option names keys for and error messages for values.
    def validate_options( manipulator, options, client )
      load( manipulator ).validate_options!( options, client )
    end

    # @param  [String]  directory Directory including manipulators.
    def library=( directory )
      @library = File.expand_path( directory ) + '/'
    end

    # @return [Array<String>] Paths of all manipulators.
    def paths
      Dir.glob( "#{library}**/*.rb" )
    end

    # @return [Array<Symbol>] Names of all manipulators.
    def available
      paths.map { |path| path_to_name path }
    end

    # @param  [Symbol]  manipulator
    #   Loads a manipulator by name.
    #
    # @return [Class] Loaded manipulator.
    def load( manipulator )
      manipulator = normalize_name( manipulator )
      return @manipulators[manipulator] if @manipulators.include? manipulator

      Kernel.load name_to_path( manipulator )
      @manipulators[manipulator]
    end

    # Loads all manipulators.
    #
    # @return [Hash]  All manipulators.
    def load_all
      paths.each { |path| load path_to_name( path ) }
      loaded
    end

    # @param  [Symbol]  manipulator
    #   Unloads a manipulator by name.
    #
    # @return [Bool]
    #   `true` if the manipulator was unloaded successfully, `false` if no
    #   matching one was found.
    def unload( manipulator )
      klass = @manipulators.delete( normalize_name( manipulator ) )
      return false if !klass

      container = self
      klass.to_s.gsub( "#{self}::", '' ).split( '::' )[0...-1].each do |c|
        container = container.const_get( c.to_sym )
      end

      container.instance_eval do
        remove_const klass.to_s.split( ':' ).last.to_sym
      end

      # Remove the container namespaces themselves if they're now empty.
      container = self
      klass.to_s.gsub( "#{self}::", '' ).split( '::' )[0...-1].each do |c|
        container = container.const_get( c.to_sym )
        if container != self && container.constants.empty?
          remove_const container.to_s.split( ':' ).last.to_sym
        end
      end

      true
    end

    # Unloads all manipulators.
    def unload_all
      @manipulators.keys.each { |manipulator| unload manipulator }
      nil
    end

    # @param    [Block] block
    #   Block to be passed each manipulator name=>class.
    # @return   [Enumerator, Manipulators]
    #   `Enumerator` if no `block` is given, `self` otherwise.
    def each( &block )
      return enum_for( __method__ ) if !block_given?
      @manipulators.each( &block )
      self
    end

    # @return [Hash]  All manipulators as a frozen hash.
    def loaded
      @manipulators.dup.freeze
    end

    # Registers a manipulator.
    #
    # @param  [Symbol]  name
    # @param  [Base]  klass
    #
    # @return [Manipulator] `self`
    #
    # @private
    def register( name, klass )
      @manipulators[normalize_name( name )] = klass
      self
    end

    # Resets the manipulators by unloading all and settings the {#library} to
    # its default setting.
    def reset
      unload_all if @manipulators

      @library      = File.expand_path( File.dirname( __FILE__ ) + '/manipulators' ) + '/'
      @manipulators = {}
    end

    # @param  [String]  name  Manipulator name.
    # @return [Bool]  `true` if the given manipulator exists, `false` otherwise.
    def exist?( name )
      File.exist? name_to_path( name )
    end

    # @param  [String]  path  FS path to a manipulator.
    # @return [String]  Manipulator shortname.
    def path_to_name( path )
      normalize_name path.gsub( library, '' ).gsub( /(.+)\.rb$/, '\1' )
    end

    # @param  [Class]  klass  Manipulator class.
    # @return [String, nil]
    #   Manipulator shortname, `nil` if the manipulator isn't loaded.
    def class_to_name( klass )
      @manipulators.select { |name, k| return name if k == klass }
      nil
    end

    # @param  [String]  name  Manipulator shortname.
    # @return [String]  Manipulator FS path.
    def name_to_path( name )
      File.expand_path "#{library}/#{name}.rb"
    end

    # @param  [String, Symbol]  name  Manipulator name.
    # @return [String]  Manipulator name.
    def normalize_name( name )
      name.to_s
    end
  end

  reset

end
end
end
end
