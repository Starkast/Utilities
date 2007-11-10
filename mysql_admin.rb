#!/usr/local/bin/ruby

require 'optparse'
require 'ostruct'
require '/opt/generate_password.rb'

def execute_sql(sql)
#  command = "/usr/local/bin/mysql -u root -p -e \"#{sql}\""
  command = "echo \"#{sql}\"|/usr/local/bin/mysql -u root -p"
#  puts command
#  exit
  result = `#{command}`.strip
  return result if $?.exitstatus == 0
  $stderr.puts "Failed to execute: #{command}"
  exit 1
end

def add_user(username)
  password = generate_password
  sql = "CREATE USER '#{username}'@'localhost' IDENTIFIED BY '#{password}';

GRANT USAGE ON * . * TO '#{username}'@'localhost' IDENTIFIED BY '#{password}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;

GRANT ALL PRIVILEGES ON \\`#{username}\%\\` . * TO '#{username}'@'localhost';"

  puts "User #{username} created with password #{password}" if execute_sql(sql) 
end

def edit_user(username)
  password = generate_password
  sql = "SET PASSWORD FOR '#{username}'@'localhost' = PASSWORD('#{password}');"
  puts "Change password for #{username} to #{password}" if execute_sql(sql)  
end

def delete_user(username)
  sql = "DROP USER '#{username}'@'localhost';"
  puts "Deleted user #{username}" if execute_sql(sql)  
end

# Just do some checks

# Specify the options and parse the arguments
options = OpenStruct.new
ARGV << '-h' if ARGV.empty?
ARGV.options do |opts|
  opts.separator "One of these is required:"
  opts.on('-a', '--add USERNAME',
          'Add a new user', String) {|options.add|}
  opts.on('-e', '--edit USERNAME',
          'Generate new password for existing user', String) {|options.edit|}
  opts.on('-d', '--delete USERNAME',
          'Delete a user', String) {|options.delete|}
  opts.on('-h', '--help', 'Show usage') do
    puts opts
    exit
  end

  opts.parse!

  if ENV['USER'] != 'root'
    puts "You are not root!"
    exit 1
  elsif options.respond_to?(:add)
    add_user(options.add)
  elsif options.respond_to?(:edit)
    edit_user(options.edit)
  elsif options.respond_to?(:delete)
    delete_user(options.delete)
  else
    puts "Should not happen?"
  end
end
