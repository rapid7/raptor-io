#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'
require 'securerandom'

target_uri =  ARGV[0]

http_client =  RaptorIO::Protocol::HTTP::Client.new(switch_board: RaptorIO::Socket::SwitchBoard.new)

# Set the Content-Type to JSON
ctype_headers = { 'Content-Type' => 'application/json' }

# Benign bogus request to set a baseline for the behavior
baseline_data = "{ \"#{SecureRandom.hex(rand(8)+1)}\" : \"#{SecureRandom.hex(rand(8)+1)}\" }"
first_response = http_client.post target_uri, body: baseline_data, headers: ctype_headers, raw: true, mode: :sync

if first_response.nil?
  puts "Got no response from #{target_uri} to the initial JSON request"
  exit
elsif first_response.code =~ /^[4,5]/
  puts "Got #{first_response.code} #{first_response.message} for #{target_uri}"
  puts "Double-check your URI"
  exit
end

# Deserialize a hash, this should work if YAML deserializes.
second_data = "--- {}\n".gsub(':', '\u003a')
second_response = http_client.post target_uri, body: second_data, headers: ctype_headers, raw: true, mode: :sync

if second_response.nil?
  puts "No response to the initial YAML probe"
  exit
end

# Deserialize a malformed object, inducing an error.
third_data = "--- !ruby/object:\x00".gsub(':', '\u003a')
third_response = http_client.post target_uri, body: third_data, headers: ctype_headers, raw: true, mode: :sync

if third_response.nil?
  puts "No response to the second YAML probe"
  exit
end

puts "Probe Response Codes were #{first_response.code} , #{second_response.code} , #{third_response.code} "

if (second_response.code == first_response.code) and (third_response.code != second_response.code) and (third_response.code != 200)
  puts "Target (#{target_uri}) is likely VULNERABLE due to the response to the YAML probes"
else
  puts "Target (#{target_uri}) is likely NOT vulnerable due to the response to the YAML probes"
end

