ServiceManager.define_service "client" do |s|

  # this is the host and port the service will be available on. If something is responding here, don't try to start it again because it's already running
  s.host       = "localhost"
  s.port       = 9292

  s.start_cmd  = "ruby client.rb -p #{s.port}"

  # When this regexp is matches, ServiceManager will know that the service is ready
  s.loaded_cue = /Listening on .*\:\d+, CTRL\+C to stop/

  # ServiceManager will colorize the output as specified by this terminal color id.
  s.color      = 34

  # The directory
  s.cwd        = Dir.pwd + "/spec/support/webservers/raptor/protocols/http/"
end
ServiceManager.define_service "client_https" do |s|

  # this is the host and port the service will be available on. If something is responding here, don't try to start it again because it's already running
  s.host       = "localhost"
  s.port       = 9293

  s.start_cmd  = "ruby client_https.rb -p #{s.port}"

  # When this regexp is matches, ServiceManager will know that the service is ready
  s.loaded_cue = /INFO  WEBrick::HTTPServer#start:/

  # ServiceManager will colorize the output as specified by this terminal color id.
  s.color      = 35

  # The directory
  s.cwd        = Dir.pwd + "/spec/support/webservers/raptor/protocols/http/"
end
ServiceManager.define_service "client_close_connection" do |s|

  # this is the host and port the service will be available on. If something is responding here, don't try to start it again because it's already running
  s.host       = "localhost"
  s.port       = 9294

  s.start_cmd  = "ruby client_close_connection.rb -p #{s.port}"

  # When this regexp is matches, ServiceManager will know that the service is ready
  s.loaded_cue = /Listening for connections/

  # ServiceManager will colorize the output as specified by this terminal color id.
  s.color      = 36

  # The directory
  s.cwd        = Dir.pwd + "/spec/support/webservers/raptor/protocols/http/"
end
