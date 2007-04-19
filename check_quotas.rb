#!/usr/local/bin/ruby

# Skickar ett fint brev till anv�ndaren
def mail_user username, used, soft, dir
  message = "Hej #{username}!

Det h�r �r ett automatiskt genererat brev fr�n servern Phoo, 
<http://phoo.starkast.net> som du har konto p�.

Vi vill tala om f�r dig att du anv�nder f�r mycket utrymme.

Katalog: #{dir}/#{username}
Just nu: #{used.to_i / 1024} MiB 
Din gr�ns: #{soft.to_i / 1024} MiB

Det �r #{(used.to_i - soft.to_i) / 1024} MiB f�r mycket.
Om du inte *rensar* kommer du inte kunna ladda upp nya filer.

Beh�ver du hj�lp eller mer utrymme? Svara p� det h�r mailet
och f�rklara dina behov, s� ska vi se vad vi kan g�ra.

Mvh Starkast <kontakt@starkast.net>"

  `echo "#{message}" | mail -s "[Starkast] Diskutrymme p� Phoo" #{username}`
end

# Informerar root
def mail_root username, used, soft, dir
  message = "#{Time::now}\n\nMail har g�tt iv�g till anv�ndaren: #{username}\n\n"
  message += "Katalog: #{dir}/#{username}\n"
  message += "Anv�nt: #{used.to_i / 1024} MiB\n"
  message += "Gr�ns: #{soft.to_i / 1024} MiB\n"
  message += "#{(used.to_i - soft.to_i) / 1024} MiB f�r mycket."
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

# Kontrollerar quota f�r alla anv�ndare
def checkquota(dir)
  command = "repquota " + dir
  output = `#{command}`
  filename = "bad_" + dir.split('/').join('_').sub('_','') + "_users"

  $users = Hash::new

  if not File::exist?(filename)
    `touch #{filename}`
  end
  
  # L�s in anv�ndare som l�g �ver f�rra g�ngen vi k�rde
	File::open(filename) do |file|
    while line = file.gets
      $users[$1] = $2.to_i if line =~ /^(.+?) (\d+)$/
    end
  end

	# G� igenom alla rader fr�n repquota-outputen
	lines = output.split "\n"
  lines.each do |line|
		if line =~ /^(\S?[a-z]+)\s*(\W{2})\s*(\d+)\s+(\d+)/
			username = $1
			mark = $2
			used = $3.to_i
			soft = $4.to_i

			# Anv�ndare �ver quota unders�ker vi n�rmare
			if mark.include?("+")

				# Om det �r f�rsta g�ngen skickar vi ett mail
				if !$users.has_key?(username)
					puts "f�rsta g�ngen f�r #{username}" if $DEBUG
					$users[username] = Time::now.to_i
					#mail1 username, used, soft, dir

				# Om det �r andra g�ngen skickar vi ett annat mail,
				# om anv�ndaren funnits i $users i 7 dagar
				elsif $users[username] != 0 and 
				(Time::now.to_i - $users[username]) >= (7*24*60*60)
					puts "andra g�ngen f�r #{username}" if $DEBUG
					$users[username] = 0
					#mail2 username, used, soft, dir
				end

			# Anv�ndare under quota tar vi bort om de finns i $users
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
