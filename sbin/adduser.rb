#!/usr/bin/env ruby

#
# - Create MySQL user solution is unsecure
# - If you enter wrong MySQL password two times not all text that
# should be printed is (e.g. please run rmuser)
#

require 'optparse'
require 'ostruct'
#require '/opt/mysql_admin.rb'

$mail_alias_file = '/etc/mail/aliases'

def generate_password(l=10)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('1'..'9').to_a
  chars = chars - ['o', 'O', 'i', 'I']
  return Array.new(l) { chars[rand(chars.size)] }.join
end

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
  if $user_created
    username = $user_created
    $user_created = false
    puts "Failed completing all steps to set up new user.\n"
    rmuser(username)
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
  execute_command("/usr/bin/newaliases")
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
  execute_command("/usr/bin/newaliases")
end

def create_dir(dir, chown, chmod)
  execute_command("/bin/mkdir #{dir}") if not File.exist?(dir)
  execute_command("/usr/sbin/chown #{chown} #{dir}")
  execute_command("/bin/chmod #{chmod} #{dir}")
end

def build_configs(mtree = false, bind = false, web = false)
  execute_command("/usr/local/bin/ruby /usr/local/sbin/create_mtree.rb -f /etc/supervise/home.mtree") if mtree
  execute_command("/usr/local/bin/ruby /usr/local/sbin/create_mtree.rb -f /etc/supervise/www.mtree") if mtree
  load("/usr/local/sbin/create_bind_users_include.rb", true) if bind
  execute_command("/bin/cp /etc/Starkast-Utilities/nginx.yml #{web}/etc") if web
end

def send_welcome_mail(username, passwd, mysql_passwd)
  admin = ENV['SUDO_USER']
  subject = "[Starkast] Anv�ndare skapad p� #{execute_command("hostname")}"
  message = "Hej,
  
Ditt konto �r nu skapat.

Anv�ndarnamn: #{username}
L�senord: #{passwd}

Du b�r byta l�senord s� fort som m�jligt. Du g�r det genom att k�ra 
kommandot passwd n�r du loggat in med SSH.

Du loggar in genom att anv�nda SSH/SCP/SFTP och ansluta till: 
ssh.starkast.net port 22.

Adressen http://#{username}.starkast.net har pekats till ditt utrymme, 
det kan dock dr�ja upp till 20 minuter tills pekningen �r genomf�rd.

Du kan lagra 1 GiB i din hemkatalog.
K�r kommandot quota f�r att se hur du ligger till med utrymmet.

En anv�ndare till MySQL har skapats. Se inloggninsuppgifter nedan. Du 
f�r skapa de databaser du beh�ver sj�lv. Se http://wiki.starkast.net/MySQL

Anv�ndarnamn: #{username}
L�senord: #{mysql_passwd}

Viktigt: Du f�r inte ladda upp st�tande, pornografisk eller olagligt 
material p� servern. Vi garanterar inte heller din data, h�ll egen 
backup om den �r viktig. 

P� v�r wiki finns det information om hur du anv�nder de olika 
tj�nsterna. Du hittar den p� http://wiki.starkast.net/.

Om du undrar �ver n�got annat, hoppa in i #starkast p� QuakeNet
eller skicka ett mail till kontakt@starkast.net.

Mvh Starkast"

  `echo "#{message}"|mail -b root -s '#{subject}' #{username}`
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
  opts.on('-M', '--send-mail', 
          'Send welcome mail')               {|options.send_mail|}
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
  comment = "-c '#{options.name}'" # Name
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
    create_dir("#{wwwdir}/logs", "#{options.username}:www", "0770")

    # Create symlink in ~
    execute_command("/bin/ln -s #{wwwdir} #{homedir}/www")

    # Create mtree and web configs and point hostname
    build_configs(mtree = true, bind = true, web = wwwdir)

    # chown web config
    execute_command("/usr/sbin/chown #{options.username}:#{options.username} #{wwwdir}/etc/nginx.yml")

    # Install php.ini
    execute_command("/usr/local/sbin/install_php_ini.rb -u #{options.username}")

    # Build the web config
    execute_command("/usr/bin/env WEBCTL_USER=#{options.username} /usr/local/bin/webctl -r")

    
    # Spawn PHP
    # does not work good enough, run manually
    #execute_command("/opt/spawn-php-fcgi.sh")

    # Restart Nginx
    execute_command("/usr/bin/pkill -HUP -U root -x nginx")

    # Print instructions for stuff to do manually
    puts "Don't forget to:"

    # Command to create MySQL user
    mysql_passwd = generate_password
    puts " * Create MySQL user and database:"
    puts "   /usr/local/sbin/mysql_admin.rb -a #{options.username} -p #{mysql_passwd}"
    puts "   You will be asked for the MySQL root password when you do this!"
    puts "   (ignore this if you are creating the user for the second time)"

    # SOA and reload
    puts " * Bump SOA serial in /var/named/master/starkast.net on the machine that is
   BIND master Reload BIND:"
    puts "   rndc reload starkast.net"

    # Spawn PHP
    puts " * Spawn PHP processes:"
    puts "   sudo /usr/local/sbin/spawn-php-fcgi.sh"

    # Quota
    puts " * Set qouta limits to soft=1048576, hard=1310720:"
    puts "   sudo edquota #{options.username}"

    # For the other machines
    uid = `id -u #{options.username}`.strip
    gid = `id -g #{options.username}`.strip
    arguments_to_script = "-l #{options.username} -E #{options.email} -N '#{options.name}' "

    puts " * Create the user on the other machines, if you haven't done it already:"
    puts "   sudo #{$0} #{arguments_to_script} -u #{uid} -g #{gid}"

    puts " * Copy the password from master.passwd on this machine to the other 
   machines master.passwd"

    if options.send_mail
      # Send a welcome mail to the user
      if send_welcome_mail(options.username, passwd, mysql_passwd)
        puts "\nWelcome mail sent to #{options.username} (#{options.email})."
      else
        puts "Error sending mail to #{options.username} (#{options.email})."
      end
    else
      puts "Did NOT send email to #{options.username}"
    end
    
  else
    puts "You should never se this."
  end
end
