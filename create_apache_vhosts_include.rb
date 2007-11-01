#!/usr/bin/env ruby

require '/opt/lib/phoo.rb'

sites = Phoo::Sites.find('/var/www/users/*/vhosts/*') + \
  Phoo::Sites.find('/var/www/users/*/htdocs') + \
  Phoo::Sites.find('/var/www/vhosts/*')

File.open('/var/www/conf/vhosts.conf', 'w') do |f|
  sites.each do |site|
  f.puts <<EOF
# #{site.domain} by #{site.user}
<VirtualHost 127.0.0.1:80>
  ServerName #{site.domain}
  ServerAlias www.#{site.domain}
  DocumentRoot #{site.path}
  php_value mail.force_extra_parameters "-f#{site.user || 'www'}@phoo.starkast.net"
</VirtualHost>

EOF
  end
end
