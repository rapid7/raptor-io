#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'
require 'optparse'

options = {}

myopts = OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("--url <URL>", "Full URL of the Tomcat Mgr app to login to") do |url|
    options[:url] = url
  end

  opts.on("--username <USERNAME>", "Username to attempt to login with") do |username|
    options[:username] = username
  end

  opts.on("--password <PASSWORD>", "Password to attempt to login with") do |password|
    options[:password] = password
  end



end

myopts.parse!

http_client =  RaptorIO::Protocol::HTTP::Client.new(switch_board: RaptorIO::Socket::SwitchBoard.new)

puts "Sending Test request for Authentication challenge"
test_response = http_client.get options[:url], mode: :sync

if test_response.code != 401
  puts "Did not request authorization. Make sure you have the URL right"
  exit
end

get_opts = {
  mode: :sync, manipulators: {
    'authenticators/basic' =>
    {
      username: options[:username],
      password: options[:password]
    }
  }
}

puts "Sending login #{options[:username]}:#{options[:password]}"
tomcat_login_response =  http_client.get options[:url], get_opts


if tomcat_login_response.code == 200
  puts "LOGIN SUCCESSFUL! (#{options[:username]}:#{options[:password]})"
else
  puts "LOGIN FAILED (#{options[:username]}:#{options[:password]})"
end

