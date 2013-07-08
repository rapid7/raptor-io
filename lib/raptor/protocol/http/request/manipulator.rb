module Raptor
module Protocol::HTTP

# Namespace holding all Request manipulators and providing some helper methods
# for management.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
class Request

# Base manipulator class, all manipulator components should inherit from it.
#
# @author Tasos Laskos <tasos_laskos@rapid7.com>
# @abstract
class Manipulator

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

  class <<self

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
