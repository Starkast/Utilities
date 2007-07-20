#!/usr/local/bin/ruby

# Example:
# 
#  special = {'graddan' => {:gid => '10006', :mode => '0775'},
#             'scrooge' => {:gid => '1033', :mode => '0775'}}
#  default = {:mode => '0750'}
#
#  mtree = Mtree.new(default, special)
#  mtree.create_for('/ustorage/home')
# 

begin
  require 'optparse'
rescue LoadError
  $stderr.puts 'Could not load required libraries'; exit 1
end

$config_path = ''
ARGV.options do |opts|
  opts.on('-f', '--file FILE', 'Configuration file') {|$config_path|}
  opts.on('-h', '--help', 'Show usage') do
    puts opts
    exit
  end
  opts.parse!
  if $config_path.empty?
    puts opts
    exit 1
  end
end

begin
  load $config_path
rescue LoadError
  $stderr.puts "Could not load #$config_path"; exit 1
end

class Mtree
  def initialize
    @setting         = {}
    @override        = $override || {}
    @setting.default = $default if $default
    @setting.merge!($special)   if $special

    unless File.directory?($directory)
      puts "Could not find #$directory"; exit 1
    end

    unless File.writable?($output) or File.writable?(File.dirname($output))
      puts "Can not write to #$output"; exit 1
    end

    begin
      create_for($directory) 
    rescue Errno::ENOENT
      puts "Could not read #$directory"
      exit 1
    end
  end

private

  # It is important that the "tree:"-row is the third row!
  def create_for(directory)
    File.open($output, 'w') do |f|
      f.puts "#"
      f.puts "#"
      f.puts "# tree: #{directory}"
      f.puts "# date: #{Time.now}"
      f.puts '. type=dir'
      Dir.new(directory).each do |u|
        next if u =~ /\..?/
        f.puts "#{u} type=dir uid=#{uid(u)} gid=#{gid(u)} mode=#{mode(u)} nlink=2 ignore\n.."
      end
    end
  end

  def uid(user)
    @override[:uid] || @setting[user][:uid] || `id -u #{user}`.strip
  end

  def gid(user)
    @override[:gid] || @setting[user][:gid] || `id -g #{user}`.strip
  end

  def mode(user)
    @override[:mode] || @setting[user][:mode]
  end
end

Mtree.new
