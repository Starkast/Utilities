#!/usr/local/bin/ruby

# Skickar ett fint brev till användaren
def mail_user username, used, soft, dir
  message = "Hej #{username}!

Det här är ett automatiskt genererat brev från servern Phoo, 
<http://phoo.starkast.net> som du har konto på.

Vi vill tala om för dig att du använder för mycket utrymme.

Katalog: #{dir}/#{username}
Just nu: #{used.to_i / 1024} MiB 
Din gräns: #{soft.to_i / 1024} MiB

Det är #{(used.to_i - soft.to_i) / 1024} MiB för mycket.
Om du inte *rensar* kommer du inte kunna ladda upp nya filer.

Behöver du hjälp eller mer utrymme? Svara på det här mailet
och förklara dina behov, så ska vi se vad vi kan göra.

Mvh Starkast <kontakt@starkast.net>"

  `echo "#{message}" | mail -s "[Starkast] Diskutrymme på Phoo" #{username}`
end

# Informerar root
def mail_root username, used, soft, dir
  message = "#{Time::now}\n\nMail har gått iväg till användaren: #{username}\n\n"
  message += "Katalog: #{dir}/#{username}\n"
  message += "Använt: #{used.to_i / 1024} MiB\n"
  message += "Gräns: #{soft.to_i / 1024} MiB\n"
  message += "#{(used.to_i - soft.to_i) / 1024} MiB för mycket."
  `echo "#{message}" | mail -s "phoo.starkast.net quota check output" root`
end

def mail username, used, soft, dir
  mail_user username, used, soft, dir
  mail_root username, used, soft, dir
end

# Testing
#mail "jage",10485760, 9484748, "/home"
#exit

$DEBUG = true

# Kontrollerar quota för alla användare
def checkquota(dir)
  command = "repquota " + dir
  output = `#{command}`
  filename = "bad_" + dir.split('/').join('_').sub('_','') + "_users"

  $users = Hash::new

  if not File::exist?(filename)
    `touch #{filename}`
  end
  
  # Läs in användare som låg över förra gången vi körde
	File::open(filename) do |file|
    while line = file.gets
      $users[$1] = $2.to_i if line =~ /^(.+?) (\d+)$/
    end
  end

	# Gå igenom alla rader från repquota-outputen
	lines = output.split "\n"
  lines.each do |line|
		if line =~ /^(\S?[a-z]+)\s*(\W{2})\s*(\d+)\s+(\d+)/
			username = $1
			mark = $2
			used = $3.to_i
			soft = $4.to_i

			# Användare över quota undersöker vi närmare
			if mark.include?("+")

				# Om det är första gången skickar vi ett mail
				if !$users.has_key?(username)
					puts "första gången för #{username}" if $DEBUG
					$users[username] = Time::now.to_i
					#mail1 username, used, soft, dir

				# Om det är andra gången skickar vi ett annat mail,
				# om användaren funnits i $users i 7 dagar
				elsif $users[username] != 0 and 
				(Time::now.to_i - $users[username]) >= (7*24*60*60)
					puts "andra gången för #{username}" if $DEBUG
					$users[username] = 0
					#mail2 username, used, soft, dir
				end

			# Användare under quota tar vi bort om de finns i $users
			else
				$users.delete_if { |u,t| u == username }
			end
		end
	end

	# sparar $users i en fil
  File::open(filename, 'w') do |file|
    $users.each do |username,time|
      file.puts "#{username} #{time}"
    end
  end
end

dirs = [ "/var/www", "/home" ]
dirs.each { |dir| checkquota(dir) }
