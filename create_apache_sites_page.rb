#!/usr/bin/env ruby

require '/opt/lib/phoo.rb'

hidden = ['jage.roden.dev.imum.net',
          'bilder.ragnarsson.nu',
          'zatte.roden.dev.imum.net']

sites = Phoo::Sites.find('/var/www/users/*/vhosts/*') + \
  Phoo::Sites.find('/var/www/users/*/htdocs') + \
  Phoo::Sites.find('/var/www/vhosts/*')

sites.delete_if {|i| hidden.include? i.domain }

File.open('/var/www/htdocs/sites.html', 'w') do |f|
  f.puts '<html>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="sv" lang="sv">
<head>
  <title>Phoo sites</title>
    <meta http-equiv="Content-type" content="text/html; charset=ISO-8859-1" />
    <link rel="stylesheet" type="text/css" href="stylesheets/default.css" />
    <link rel="shortcut icon" type="image/ico" href="/favicon.ico" />
  </head>
  <p>
    <a href="http://phoo.starkast.net/"><img src="/phoo.png" alt="Phoo.starkast.net" border="0" /></a>
  </p>'
  f.puts "<h1>#{sites.length} sites</h1>"
  f.puts "<ul>"
  sites.each do |site|
  f.puts <<EOF
  <li><a href=\"http://#{site.domain}\">#{site.domain}</li>
EOF
  end
  f.puts "</ul></body></html>"
end
