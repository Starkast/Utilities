#!/usr/local/bin/ruby

# Skickar mail
def send_mail(user, used, soft, hard, dir, first, home)

	subject = "[Starkast] Lagringsutrymme fullt"

	if first
		firstorsecond = "Detta �r din f�rsta p�minelse. Om du inte b�ttrat dig inom 7 dagar f�r du en ny."
	else
		firstorsecond = "Detta �r din andra p�minelse. Du kommer inte f� fler, och du kommer inte kunna 
skapa nya filer innan du rensat."
	end

	# Om det �r en anv�ndare som finns i /home, ber�tta vart utrymmet
	# tagit slut
	if home
		where = "Katalog: #{dir}/#{user}\n"
	end

	text = "Automatskapat e-brev fr�n Starkast!

DITT LAGRINGSUTRYMME �R SLUT
----------------------------

Du har fyllt ditt tilldelade lagringsutrymme hos Starkast, om du vill ladda upp
nya filer m�ste du rensa.

Just nu anv�nder du #{(used.to_i - soft.to_i) / 1024} MiB f�r mycket.

Anv�nt utrymme: #{used.to_i/1024} MiB
Soft quota: #{soft.to_i/1024} MiB
Hard quota: #{hard.to_i/1024} MiB
#{where}
#{firstorsecond}

INFORMATION
-----------

Varje konto har en gr�ns f�r m�ngden lagrad data, denna gr�ns �r uppdelad i tv�
delar, \"soft quota\" och \"hard quota\".

\"Soft quota\": Tillf�lligt �verskridbar gr�ns. �verskrider man denna startas 
en r�knare, n�r denna g�tt i *7 dygn* kommer filskapande f�rhindras. Du kommer 
inte kunna ladda upp n�gon data f�rr�ns m�ngden lagrad data minskats till under 
denna gr�ns.

\"Hard quota\": Maximigr�ns, det g�r *aldrig* att �verskrida denna."

	`echo "#{text}" | mail -s "#{subject}" #{user}`
end


# send_mail(user, used, soft, hard, dir, first, home)
#send_mail("dentarg", 67862742, 524288, 1048576, "/var/www", true, true)
#send_mail("dentarg", 67862742, 524288, 1048576, "/var/www", true, false)
#send_mail("dentarg", 67862742, 524288, 1048576, "/home", true, true)


$DEBUG = false

$homeusers = `ls -1 /home`.split(/\n/)

# Kontrollerar quota f�r alla anv�ndare
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
  
	# L�s in anv�ndare som l�g �ver f�rra g�ngen vi k�rde
	File::open(filename) do |file|
    while line = file.gets
      $users[$1] = $2.to_i if line =~ /^(.+?) (\d+)$/
    end
  end

	# G� igenom alla rader fr�n repquota-outputen
	lines = output.split("\n")
  lines.each do |line|
		if line =~ /^(\S?[a-z]+)\s*(\W{2})\s*(\d+)\s+(\d+)\s+(\d+)/
			user = $1
			mark = $2
			used = $3.to_i
			soft = $4.to_i
			hard = $5.to_i

			# Anv�ndare �ver quota unders�ker vi n�rmare
			if mark.include?("+")

				# Om det �r f�rsta g�ngen skickar vi ett mail
				# samt sparar tidpunkten f�r uppt�ckten

				if !$users.has_key?(user)

					puts "First time: #{user}" if $DEBUG
					$users[user] = Time::now.to_i
					send_mail(user, used, soft, hard, partion, true, $homeusers.include?(user))

				# Om det �r andra g�ngen skickar vi ett annat mail,
				# om anv�ndaren funnits i $users i 7 dagar
				# samt s�tter tiden till 0 s� vi inte skickar mail igen

				elsif $users[user] != 0 and 
				(Time::now.to_i - $users[user]) >= (7*24*60*60)

					puts "Second time: #{user}" if $DEBUG
					$users[user] = 0
					send_mail(user, used, soft, hard, partion, false, $homeusers.include?(user))
					
				end

			# Anv�ndare som inte �verstiger sin quota tar vi bort om de finns i $users
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
