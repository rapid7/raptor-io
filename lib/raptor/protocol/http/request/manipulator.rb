module Raptor
module Protocol::HTTP

class Request

# Base manipulator class, all manipulator components should inherit from it.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
# @abstract
class Manipulator

  #
  # {HTTP::Request::Manipulator} error namespace.
  #
  # All {HTTP::Request::Manipulator} errors inherit from and live under it.
  #
  # @author Tasos "Zapotek" Laskos
  #
  class Error < Request::Error

    # Indicates invalid options for a manipulator.
    #
    # @author Tasos Laskos
    class InvalidOptions < Error
    end

  end

  # @return [HTTP::Client]  Current HTTP client instance.
  attr_reader :client

  # @return [HTTP::Request]  Request to manipulate.
  attr_reader :request

  # @return [Hash]  Manipulator options.
  attr_reader :options

  # @param  [HTTP::Client]  client
  #   HTTP client which will handle the request.
  # @param  [HTTP::Request]  request
  #   Request to process.
  def initialize( client, request, options = {} )
    @client  = client
    @request = request
    @options = options
  end

  # Delivers the manipulator's payload.
  # @abstract
  def run
  end

  def delegate( manipulator, opts = options )
    Request::Manipulators.process( manipulator, client, request, opts )
  end

  # @return [Hash]  Persistent storage -- per {HTTP::Client} instance.
  def datastore
    client.datastore[self.class.shortname]
  end

  # @return [Hash{Symbol=>Array<String>}]
  #   Option names keys for and error messages for values.
  def validate_options
    self.class.validate_options!( options, client )
  end

  class <<self

    def validate_options( &block )
      fail ArgumentError, 'Missing block.' if !block_given?
      @validator = block
    end

    #
    # @param  [Hash]  options Manipulator options.
    # @param  [HTTP::Client]  client  Applicable client.
    #
    # @return [Hash{Symbol=>Array<String>}]
    #   Option names keys for and error messages for values.
    #
    # @abstract
    def validate_options!( options, client )
      @validator ? @validator.call( options, client ) : {}
    end

    def shortname
      @shortname ||= Request::Manipulators.class_to_name( self )
    end

    # Registers {Request::Manipulators::Base manipulators} which inherit from
    # this base class.
    #
    # @see Request::Manipulators#register
    def inherited( manipulator_klass )
      Request::Manipulators.register(
          Request::Manipulators.path_to_name( caller.first.split( ':' ).first ),
          manipulator_klass
      )
    end
  end

end
end
end
end
