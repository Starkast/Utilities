#!/usr/bin/env ruby

require '/opt/lib/phoo.rb'


File.open('/var/named/includes/starkast','w') do |f|
  f.puts "; Users"
  Phoo::Sites.find('/var/www/users/*').each do |site|
    # BIND, dirty tab hack :-(
    tabs = "\t\t"
    tabs = "\t" if site.user.length >= 8
    f.puts "#{site.user}#{tabs}A\t#{$default_ip}"
    f.puts "www.#{site.user}\tA\t#{$default_ip}"
  end

  f.puts "\n; Vhosts"
    Phoo::Sites.find('/var/www/users/*/vhosts/*.starkast.net').each do |site|

    f.puts "#{site.domain}.\tA\t#{$default_ip}"
    f.puts "www.#{site.domain}.\tA\t#{$default_ip}"
  end
end
