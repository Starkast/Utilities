#!/usr/bin/env ruby

#
# Something temporary
#

$mail_alias_file = '/etc/mail/aliases'

def rmuser(username)
  # remove mail alias
  if email_remove(username)
    puts "Removed mail alias from #{$mail_alias_file}"
  end

  # remove wwwdir
  if execute_command("/bin/rm -r /var/www/users/#{username}")
    puts "Removed /var/www/users/#{username}"
  end

  # remove mtree configs and hostname
  if build_configs(mtree = true, bind = true, web = false)
    puts "Restored mtree configs and BIND config."
  end

  # remove mysql user
  execute_command("/usr/local/sbin/mysql_admin.rb -d #{username}")

  puts "\nPlease run: rmuser #{username}"
end

def execute_command(command)
  result = `#{command}`.strip
  return result if $?.exitstatus == 0
  $stderr.puts "Failed to execute: #{command}"
end

def email_remove(username)
  tmp = ""
  File::readlines($mail_alias_file).each do |line|
    line =~ /(\w+):/
    if not $1 == username
      tmp += line
    end
  end
  File::open($mail_alias_file, 'w').puts(tmp)
  execute_command("/usr/local/sbin/postalias #{$mail_alias_file}")
end

def build_configs(mtree = false, bind = false, web = false)
  execute_command("/usr/local/bin/ruby /usr/local/sbin/create_mtree.rb -f /etc/supervise/home.mtree") if mtree
  execute_command("/usr/local/bin/ruby /usr/local/sbin/create_mtree.rb -f /etc/supervise/www.mtree") if mtree
  load("/usr/local/sbin/create_bind_users_include.rb", true) if bind
  execute_command("/bin/cp /etc/Starkast-Utilities/nginx.yml #{web}/etc") if web
end

if not ARGV.empty? 
  if ENV['USER'] != 'root'
    puts "You are not root!"
    exit 1
  else
     rmuser(ARGV[0])
  end
else
  puts "Hey, I need a username!"
end
