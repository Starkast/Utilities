#!/usr/bin/env ruby

# $id$
#
# Written by Johan Eckerström <johan@jage.se>

require 'erb'

cache_time   = 6*24*60*60 # max 4 times a day
cache_file   = '/var/tmp/ftp_status.cache'
erb_template = '/opt/templates/ftp_starkast_net.erb'
html_output  = '/var/www/ftp/index.html'

# This should not be cached
load_avg = `sysctl vm.loadavg`.split('=').last.split(' ').join(', ')

d = {}
if not File.exist?(cache_file) or ((Time.now.to_i - File.new(cache_file).mtime.to_i) > cache_time)
  # Data that will be cached between runs
  d[:data_size]    = `du -sh /var/www/ftp`.split("\t").first.gsub('G', ' GiB')
  d[:total_files]  = `find /var/www/ftp -type f|wc -l`.to_i
  d[:mirror_syncs] = Dir.glob('/var/log/mirror.*').collect do |log_file|
    s = `tail -n 1 #{log_file}`.split(',')
    { :status => s[0],
      :path => s[1],
      :host => s[2],
      :updated_on => s[3] }
  end
  # Save Cache
  File.open(cache_file, 'w') do |cache_f|
    cache_f.print Marshal.dump(d)
  end
else
  # Load Cache
  d = Marshal.load(File.open(cache_file) {|fp| fp.read })
end

# This should be made nicer
data_size, total_files, mirror_syncs = d[:data_size], d[:total_files], d[:mirror_syncs]

# Parse ERB and write HTML
File.open(html_output, 'w') do |html_f|
  html_f.print File.open(erb_template) {|fp| ERB.new(fp.read) }.result
end
