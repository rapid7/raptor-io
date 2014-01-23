
class RaptorIO::Socket::CommChain
  attr_accessor :comms

  # @param uris [Array] A list of URIs (as `URI` objects or as `String`s)
  def initialize(*uris)
    @comms = [ RaptorIO::Socket::SwitchBoard::DEFAULT_ROUTE.comm ]
    uris.each do |arg|
      begin
        arg_uri = (arg.kind_of? URI) ? arg : URI.parse(arg)
      rescue URI::InvalidURIError
        raise ArgumentError.new("Invalid URI (#{arg.inspect})")
      end

      next_comm = RaptorIO::Socket::Comm.from_uri(arg_uri, prev_comm: @comms.last)

      if next_comm.kind_of? RaptorIO::Socket::Comm
        @comms << next_comm
      else
        raise ArgumentError.new("Invalid Comm: unknown scheme (#{arg_uri.scheme.inspect})")
      end
    end

  end

  def create_tcp(opts = {})
    @comms.last.create_tcp(opts)
  end

end
