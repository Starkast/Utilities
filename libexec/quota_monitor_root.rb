#!/usr/local/bin/ruby

dir = "/var/db/quota_monitor/"

# Nothing to do if no dir is found
exit 1 unless File.directory?(dir)

Dir.entries(dir)[2..-1].each do |filename|
	file = dir + filename
	if not File::zero?(file)

		puts "\nQuota overrides in: " + filename.gsub(/_/,'/')[3..-7]
		# L�s in och skriv ut anv�ndare 
		File::open(file) do |file|
			while line = file.gets
				puts "  " + $1 if line =~ /^(.+?) (\d+)$/
		  end
		end
	end
end
