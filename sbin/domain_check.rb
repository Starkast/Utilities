#!/usr/bin/env ruby

begin
  require '/opt/lib/phoo.rb'
  require 'rubygems'
  require 'net/dns/resolver'
rescue LoadError
  $stderr.puts 'Could not load required libraries'; exit 1
end

starkast_hosts = %w(
  beaver.starkast.net
  genau.starkast.net
  phoo.starkast.net
)
sites = Marshal.load(File.read('/var/www/db/sites')).collect {|key, site| key }

def resolv(sites)
  threads = []
  resolved = {}
  for site in sites do
    threads << Thread.new(site) do |domain|
      res = Net::DNS::Resolver.new
      res.query(domain, Net::DNS::A).each_address do |ip|
        resolved[domain] = ip
      end
    end
  end

  threads.each {|t| t.join }
  return resolved
end

starkast_ips = resolv(starkast_hosts).collect {|domain, ip| ip }
resolv(sites).each do |domain, ip|
  unless starkast_ips.include? ip
    $stderr.puts "NOT OK: #{domain} => #{ip}"
  end
end
