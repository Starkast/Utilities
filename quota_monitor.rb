#!/usr/local/bin/ruby

# Skickar mail
def send_mail(user, used, soft, hard, dir, first, home)

	subject = "[Starkast] Lagringsutrymme fullt"

	if first
		firstorsecond = "Detta är din första påminelse. Om du inte bättrat dig inom 7 dagar får du en ny."
	else
		firstorsecond = "Detta är din andra påminelse. Du kommer inte få fler, och du kommer inte kunna 
skapa nya filer innan du rensat."
	end

	# Om det är en användare som finns i /home, berätta vart utrymmet
	# tagit slut
	if home
		where = "Katalog: #{dir}/#{user}\n"
	end

	text = "Automatskapat e-brev från Starkast!

DITT LAGRINGSUTRYMME ÄR SLUT
----------------------------

Du har fyllt ditt tilldelade lagringsutrymme hos Starkast, om du vill ladda upp
nya filer måste du rensa.

Just nu använder du #{(used.to_i - soft.to_i) / 1024} MiB för mycket.

Använt utrymme: #{used.to_i/1024} MiB
Soft quota: #{soft.to_i/1024} MiB
Hard quota: #{hard.to_i/1024} MiB
#{where}
#{firstorsecond}

INFORMATION
-----------

Varje konto har en gräns för mängden lagrad data, denna gräns är uppdelad i två
delar, \"soft quota\" och \"hard quota\".

\"Soft quota\": Tillfälligt överskridbar gräns. Överskrider man denna startas 
en räknare, när denna gått i *7 dygn* kommer filskapande förhindras. Du kommer 
inte kunna ladda upp någon data förräns mängden lagrad data minskats till under 
denna gräns.

\"Hard quota\": Maximigräns, det går *aldrig* att överskrida denna."

	`echo "#{text}" | mail -s "#{subject}" #{user}`
end


# send_mail(user, used, soft, hard, dir, first, home)
#send_mail("dentarg", 67862742, 524288, 1048576, "/var/www", true, true)
#send_mail("dentarg", 67862742, 524288, 1048576, "/var/www", true, false)
#send_mail("dentarg", 67862742, 524288, 1048576, "/home", true, true)


$DEBUG = false

$homeusers = `ls -1 /home`.split(/\n/)

# Kontrollerar quota för alla användare
def checkquota(partion)
  command = "sudo repquota " + partion
  output = `#{command}`
	filedir = "/var/db/quota_monitor/"
  filename = filedir + "bad_" + partion.split('/').join('_').sub('_','') + "_users"

  if not File::exist?(filedir)
		puts "#{filedir} does not exist."
		exit
	end
	
	`touch #{filename}` if not File::exist?(filename)
  
  $users = Hash::new
  
	# Läs in användare som låg över förra gången vi körde
	File::open(filename) do |file|
    while line = file.gets
      $users[$1] = $2.to_i if line =~ /^(.+?) (\d+)$/
    end
  end

	# Gå igenom alla rader från repquota-outputen
	lines = output.split("\n")
  lines.each do |line|
		if line =~ /^(\S?[a-z]+)\s*(\W{2})\s*(\d+)\s+(\d+)\s+(\d+)/
			user = $1
			mark = $2
			used = $3.to_i
			soft = $4.to_i
			hard = $5.to_i

			# Användare över quota undersöker vi närmare
			if mark.include?("+")

				# Om det är första gången skickar vi ett mail
				# samt sparar tidpunkten för upptäckten

				if !$users.has_key?(user)

					puts "First time: #{user}" if $DEBUG
					$users[user] = Time::now.to_i
					send_mail(user, used, soft, hard, partion, true, $homeusers.include?(user))

				# Om det är andra gången skickar vi ett annat mail,
				# om användaren funnits i $users i 7 dagar
				# samt sätter tiden till 0 så vi inte skickar mail igen

				elsif $users[user] != 0 and 
				(Time::now.to_i - $users[user]) >= (7*24*60*60)

					puts "Second time: #{user}" if $DEBUG
					$users[user] = 0
					send_mail(user, used, soft, hard, partion, false, $homeusers.include?(user))
					
				end

			# Användare som inte överstiger sin quota tar vi bort om de finns i $users
			else
				$users.delete_if { |u,t| u == user }
			end
		end
	end

	# Spara $users i en fil
  File::open(filename, 'w') do |file|
    $users.each do |user,time|
      file.puts "#{user} #{time}"
    end
  end
end

['/ustorage'].each { |dir| checkquota(dir) }
