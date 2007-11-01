#!/usr/bin/env ruby

# $Id: rss_mixer.rb,v 1.12 2007/11/01 18:33:46 jage Exp $
# 
# Written by Johan Eckerström <johan@jage.se>
#

require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'erb'
require 'htmlentities'
require 'rss/maker'
require 'active_support'

html_output  = '/var/www/vhosts/starkast.net/index.html'
rss_output   = '/var/www/vhosts/starkast.net/index.rss'
erb_template = '/opt/templates/starkast_net.erb'
home_url     = 'http://starkast.net/'
config       = '/etc/rss_mixer.conf'

entries = []
domains = []
coder = HTMLEntities.new

begin
    load config
    raise NoFeeds if $feeds.empty?
rescue LoadError
    $stderr.puts 'Could not load configuration'; exit 1
end

# Helpers

# Credit to Cocoa for the idea
#
# Options are used to set a minimum accuracy
def age_in_swedish_words(time = Time.now)
  to_time = Time.now

  age_in_minutes = ((to_time - time) / 60).round.abs
  age_in_seconds = ((to_time - time)).round.abs

  case age_in_minutes
  when 0..1440    then "idag"
  when 1441..2880 then "1 dag sen"
  else                 "#{(age_in_minutes / 1440).round} dagar sen"
  end
end


attempts = Hash.new(0)
$feeds.each do |feed|
  begin
    rss = SimpleRSS.parse(open("http://#{feed}"))
  rescue
    attempts[feed] += 1
    if attempts[feed] < 3
      sleep 5
      retry
    else
      next
    end
  end
  domain = feed.split('/').first
  domains << domain
  entries += rss.channel.entries.collect do |entry|
    entry[:domain] = domain
    entry[:html_content] = coder.decode(entry[:content])
    entry
  end
end

entries.sort! {|x,y| y[:published] <=> x[:published] }

rss_content = RSS::Maker.make('2.0') do |m|
  m.channel.title = 'Starkast.net blog mix'
  m.channel.link  = 'http://starkast.net/'
  m.channel.description = 'Mix of blogs'
  m.items.do_sort
  entries.each do |e|
    i             = m.items.new_item
    i.title       = "#{coder.decode(e.title)} (#{e.domain})"
    i.link        = coder.decode(e.link)
    i.date        = e.published
    i.description = e.html_content
  end
end

File.open(html_output, 'w') do |html_f|
  html_f.puts File.open(erb_template) {|fp| ERB.new(fp.read) }.result
end

File.open(rss_output, 'w') do |rss_f|
  rss_f.puts rss_content
end
