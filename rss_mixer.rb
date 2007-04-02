#!/usr/bin/env ruby

# $Id: rss_mixer.rb,v 1.3 2007/04/02 14:01:43 jage Exp $
# 
# Written by Johan Eckerström <johan@jage.se>
#

require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'erb'
require 'htmlentities'
require 'rss/maker'

html_output  = '/home/jage/www/vhosts/starkast.net/index.html'
rss_output   = '/home/jage/www/vhosts/starkast.net/index.rss'
erb_template = '/opt/templates/starkast_net.erb'
home_url     = 'http://www.starkast.net/'

entries = []
domains = []
coder = HTMLEntities.new
feeds = %w[
  jage.se/feed/
  blog.dentarg.net/feed/
  blog.tigermann.net/feed/
  ludde.starkast.net/feed/
]

feeds.each do |feed|
  begin
    rss = SimpleRSS.parse(open("http://#{feed}"))
  rescue
    next
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
    i.title       = "#{e.title} (#{e.domain})"
    i.link        = e.link
    i.date        = e.date
    i.description = e.html_content
  end
end

File.open(html_output, 'w') do |html_f|
  html_f.print File.open(erb_template) {|fp| ERB.new(fp.read) }.result
end

File.open(rss_output, 'w') do |rss_f|
  rss_f.print rss_content
end

