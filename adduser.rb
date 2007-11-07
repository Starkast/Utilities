#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

$mail_alias_file = '/etc/mail/aliases'

def generate_password(l=10)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('1'..'9').to_a
  chars = chars - ['o', 'O', 'i', 'I']
  return Array.new(l) { chars[rand(chars.size)] }.join
end

def execute_command(command)
  result = `#{command}`.strip
  return result if $?.exitstatus == 0
  $stderr.puts "Failed to execute: #{command}"
  if $user_created
    username = $user_created
    $user_created = false
    
    puts "Failed completing all steps to set up new user.\n"
  
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

    puts "\nPlease run: rmuser #{username}"
    exit 1
  else
    exit 1
  end
end

def encrypt_password(passwd, login_class = 'default')
  execute_command("/usr/bin/encrypt -c #{login_class} #{passwd}")
end

def find_shell(shell)
  execute_command("which #{shell}")
end

def group_add(group, gid = nil)
  if gid
    execute_command("/usr/sbin/groupadd -g #{gid} #{group}")
  else
    execute_command("/usr/sbin/groupadd #{group}")
  end
end

def email_add(username, email)
  execute_command("echo '#{username}:\t#{email}' >> #{$mail_alias_file}")
  execute_command("/usr/local/sbin/postalias #{$mail_alias_file}")
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

def create_dir(dir, chown, chmod)
  execute_command("/bin/mkdir #{dir}") if not File.exist?(dir)
  execute_command("/usr/sbin/chown #{chown} #{dir}")
  execute_command("/bin/chmod #{chmod} #{dir}")
end

def build_configs(mtree = false, bind = false, web = false)
  execute_command("/usr/local/bin/ruby /opt/create_mtree.rb -f /etc/supervise/home.mtree") if mtree
  execute_command("/usr/local/bin/ruby /opt/create_mtree.rb -f /etc/supervise/www.mtree") if mtree
  load("/opt/create_bind_users_include.rb", true) if bind
  execute_command("/bin/cp /opt/templates/nginx.yml #{web}/etc") if web
end

def send_welcome_mail(username, passwd)
  admin = ENV['SUDO_USER']
  subject = "[Starkast] Användare skapad på #{execute_command("hostname")}"
  message = "Hej,
  
Ditt konto är nu skapat.

Användarnamn: #{username}
Lösenord: #{passwd}

Du bör byta lösenord så fort som möjligt. Du gör det genom att köra 
kommandot passwd när du loggat in med SSH.

Du loggar in genom att använda SSH/SCP/SFTP och ansluta till: 
ssh.starkast.net port 22.

Adressen http://#{username}.starkast.net har pekats till ditt utrymme, 
det kan dock dröja upp till 20 minuter tills pekningen är genomförd.

Du kan lagra 1 GiB i din hemkatalog.
Kör kommandot quota för att se hur du ligger till med utrymmet.

Viktigt: Du får inte ladda upp stötande, pornografisk eller olagligt 
material på servern. Vi garanterar inte heller din data, håll egen 
backup om den är viktig. 

På vår wiki finns det information om hur du använder de olika 
tjänsterna. Du hittar den på http://wiki.starkast.net.

Om du undrar över något annat, hoppa in i #starkast på QuakeNet
eller skicka ett mail till kontakt@starkast.net.

Mvh Starkast"

  `echo "#{message}"|mail -s '#{subject}' #{username}`
end

# Specify the options and parse the arguments
options = OpenStruct.new
ARGV.options do |opts|
  opts.separator "Required:"
  opts.on('-l', '--username USERNAME', 
          'Username used for login', String) {|options.username|}
  opts.on('-E', '--email EMAIL', 
          'Complete email', String)          {|options.email|}
  opts.on('-N', '--name NAME',
          'Complete name', String)           {|options.name|}
  opts.separator ""
  opts.separator "Optional:"
  opts.on('-u', '--uid UID',
          'UID for the new user', Integer)   {|options.uid|}
  opts.on('-g', '--gid GID',
          'GID for the new user', Integer)   {|options.gid|}
  opts.on('-G', '--group GROUP[,GROUP]',
          'Secondary groups', String)        {|options.group|}
  opts.on('-s', '--shell SHELL', 
          'Login shell', String)             {|options.shell|}
  opts.on('-L', '--login-class CLASS',
          'Login class', String)             {|options.login_class|}
  opts.on('-h', '--help', 'Show usage') do
    puts opts
    exit
  end

  if ARGV.empty?
    puts opts
    exit
  elsif ENV['USER'] != 'root'
    puts "You are not root!"
    exit 1
  end
  
  opts.parse!
  
  required = [ :username, :email, :name ]
  required.each do |option|
    if not options.respond_to?(option)
      puts "You forgot to specify #{option}."
      exit 1
    end
  end


  # Password
  passwd = generate_password
  epasswd = encrypt_password(passwd)
  epasswd = encrypt_password(passwd, options.login_class) if options.respond_to?(:login_class)

  # Variables to pass on to useradd

  # Required
  user = options.username
  comment = "-c '#{options.name}'"
  password = "-p '#{epasswd}'"

  # Optional
  uid = "-u #{options.uid}" if options.respond_to?(:uid)
  if options.respond_to?(:gid) 
    gid = "-g #{options.gid}"
    group_add(options.username, options.gid)
  else
    gid = "-g #{options.username}"
    group_add(options.username)
  end
  if options.respond_to?(:group)
    secondary_group = "-G users,#{options.group}"
  else
    secondary_group = "-G users"
  end
  shell = "-s #{find_shell(options.shell)}" if options.respond_to?(:shell)
  login_class = "-L #{options.login_class}" if options.respond_to?(:login_class)

  # Command
  useradd = "/usr/sbin/useradd #{comment} -m #{secondary_group} " + 
    "#{gid} #{login_class} #{password} #{shell} #{uid} #{user}"

  # Execute
  if execute_command(useradd)

    $user_created = options.username

    # Put email in /etc/mail/aliases and run postalias
    email_add(options.username, options.email)
    
    # Set permissions on homedir
    homedir = "/home/#{options.username}"
    create_dir(homedir, "#{options.username}:#{options.username}", "0750")
    execute_command("/usr/sbin/chown #{options.username}:#{options.username} #{homedir}")
    execute_command("/bin/chmod 0750 #{homedir}")

    # Create web directories
    wwwdir = "/var/www/users/#{options.username}"
    create_dir(wwwdir, "#{options.username}:www", "0750")
    create_dir("#{wwwdir}/etc", "#{options.username}:#{options.username}", "0750")
    create_dir("#{wwwdir}/htdocs", "#{options.username}:www", "0750")
    create_dir("#{wwwdir}/vhosts", "#{options.username}:www", "0750")
    create_dir("#{wwwdir}/tmp", "#{options.username}:#{options.username}", "0700")

    # Create symlink in ~
    execute_command("/bin/ln -s #{wwwdir} #{homedir}/www")

    # Create mtree and web configs and point hostname
    build_configs(mtree = true, bind = true, web = wwwdir)

    # chown web config
    execute_command("/usr/sbin/chown #{options.username}:#{options.username} #{wwwdir}/etc/nginx.yml")

    # Install php.ini
    execute_command("/opt/install_php_ini.rb -u #{options.username}")

    # Build the web config
    execute_command("/usr/bin/sudo -u #{options.username} /opt/webctl -r")

    # Spawn PHP
    execute_command("/opt/spawn-php-fcgi.sh")

    # Restart Nginx and Apache
    execute_command("/usr/bin/pkill -HUP -U root -x nginx")
    execute_command("/opt/apache_restart.sh")

    # SOA and reload
    puts "Glöm inte att: \n"
    puts " - Bumpa SOA serial i /var/named/master/starkast.net"
    puts " - rndc reload starkast.net"

    # Quota
    puts " - sudo edquota #{options.username} (soft=1048576, hard=1310720)"

    # Send a welcome mail to the user
    if send_welcome_mail(options.username, passwd)
      puts "\nWelcome mail sent to #{options.username} (#{options.email})."
    else
      puts "Error sending mail to #{options.username} (#{options.email})."
    end
    
  else
    puts "You should never se this."
  end
end
