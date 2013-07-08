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

    # @param  [Symbol]  manipulator
    #   Manipulator to run -- will be loaded if needed.
    # @param  [HTTP::Client]  client
    #   HTTP client which will handle the request.
    # @param  [HTTP::Request]  request
    #   Request to process.
    # @param  [Hash]  options
    #   Manipulator options.
    def process( manipulator, client, request, options = {} )
      load( manipulator ).new( client, request, options ).run
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

    def path_to_name( path )
      normalize_name path.gsub( library, '' ).gsub( /(.+)\.rb$/, '\1' )
    end

    def class_to_name( klass )
      @manipulators.select { |name, k| return name if k == klass }
      nil
    end

    def name_to_path( name )
      File.expand_path "#{library}/#{name}.rb"
    end

    def normalize_name( name )
      name.to_s
    end
  end
  reset

end
end
end
end
