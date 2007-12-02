#!/usr/bin/env ruby

# $Id: ftp_status.rb,v 1.7 2007/12/02 12:16:12 jage Exp $
#
# Written by Johan Eckerström <johan@jage.se>

require 'erb'

cache_time   = 6*60*60 # max 4 times a day
cache_file   = "/var/tmp/ftp_status_for_#{`whoami`.strip}.cache"
erb_template = '/opt/templates/ftp_starkast_net.erb'
html_output  = '/var/www/ftp/index.html'

# Use instance variables in the ERB-code
# c[:data_size] will be expanded to @data_size

# This should not be cached
@load_avg = `sysctl vm.loadavg`.split('=').last.split(' ').join(', ')

c = {}
if not File.exist?(cache_file) or ((Time.now.to_i - File.new(cache_file).mtime.to_i) > cache_time)
  # Data that will be cached between runs
  c[:data_size]    = `du -sh /var/www/ftp`.split("\t").first.gsub('G', ' GiB')
  c[:total_files]  = `find /var/www/ftp -type f|wc -l`.to_i
  c[:mirror_syncs] = Dir.glob('/var/log/mirror.*').collect do |log_file|
    s = `tail -n 1 #{log_file}`.split(',')
    next if s.length != 4
    { :status     => s[0],
      :path       => s[1],
      :host       => s[2],
      :updated_on => s[3] }
  end.compact!
  # Save Cache
  File.open(cache_file, 'w') do |cache_f|
    cache_f.print Marshal.dump(c)
  end
else
  # Load Cache
  c = Marshal.load(File.open(cache_file) {|fp| fp.read })
end

# Create instance variables from the c hash
c.each_pair do |key, value|
  self.instance_variable_set "@#{key.to_s}", value
end

# Parse ERB and write HTML
File.open(html_output, 'w') do |html_f|
  html_f.print File.open(erb_template) {|fp| ERB.new(fp.read) }.result
end
