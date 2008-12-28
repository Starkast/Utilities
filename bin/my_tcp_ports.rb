#!/usr/local/bin/ruby

i=`id -u`.to_i*10
puts "You\'ve got TCP port #{i} to #{i+9} on localhost (127.0.0.1)"
