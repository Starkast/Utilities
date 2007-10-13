#!/usr/local/bin/ruby

def generate_password(l=10)
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('1'..'9').to_a
  chars = chars - ['o', 'O', 'i', 'I']
  return Array.new(l) { chars[rand(chars.size)] }.join
end
