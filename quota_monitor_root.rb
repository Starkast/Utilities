#!/usr/local/bin/ruby

dir = "/var/db/quota_monitor/"

Dir.entries(dir)[2..-1].each do |filename|
	file = dir + filename
	if not File::zero?(file)

		puts "\nQuota-busar i " + filename.gsub(/_/,'/')[3..-7]
		# Läs in och skriv ut användare 
		File::open(file) do |file|
			while line = file.gets
				puts "  " + $1 if line =~ /^(.+?) (\d+)$/
		  end
		end
	end
end
