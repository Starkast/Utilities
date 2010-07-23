#!/usr/local/bin/ruby

require 'erb'
require 'optparse'
require 'fileutils'

$user = ''
ARGV << '-h' if ARGV.empty?
ARGV.options do |opts|
  opts.on('-u', '--user USER', 'Install config for USER', String) {|$user|}
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
  opts.parse!
end

exit 1 if $user == ''

$template = '/etc/Starkast-Utilities/php.ini.erb'
$path = "/var/www/users/#{$user}/etc/php.ini"

begin
  raise 'User already has a php.ini!' if File.exist?($path)
  File.open($path, 'w') do |fp|
    fp.print ERB.new(File.read($template), nil, '>').result(binding)
  end
  FileUtils.chown($user, $user, $path)
rescue => e
  $stderr.puts e
  exit 1
end
