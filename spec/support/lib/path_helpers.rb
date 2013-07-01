def manipulator_fixtures_path
  "#{fixtures_path}/raptor/protocol/http/request/manipulators"
end

def fixtures_path
  "#{spec_path}support/fixtures/"
end

def spec_path
  File.expand_path( "#{File.dirname( __FILE__ )}/../.." ) + '/'
end
