#!/usr/bin/env ruby

require '/usr/local/lib/phoo.rb'

exclude = %w(im ftp secure drift wiki teewars support)


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
      next if exclude.include?(site.domain.split('.').first)

      f.puts "#{site.domain}.\tA\t#{$default_ip}"
      f.puts "www.#{site.domain}.\tA\t#{$default_ip}"
  end

  f.puts "\n; Main vhosts"
    Phoo::Sites.find('/var/www/vhosts/*.starkast.net').each do |site|
      next if exclude.include?(site.domain.split('.').first)

      f.puts "#{site.domain}.\tA\t#{$default_ip}"
      f.puts "www.#{site.domain}.\tA\t#{$default_ip}"
  end
end
