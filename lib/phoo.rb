#!/usr/bin/env ruby

require 'pathname'

module Phoo
  $default_domain = 'starkast.net'
  $default_ip     = '212.112.166.243'
  $user_directory = /^\/var\/www\/users\/([\w]+)(\/|$)/
  $ignore_dirs    = /vhosts/
  
  class Sites
    def self.find(path)
      Dir.glob("#{path}").collect do |directory|
        begin
          next if not File.directory?(directory)
          Site.new(directory) if Pathname.new(directory).realpath
        rescue Errno::ENOENT
          next
        end
      end.compact
    end
  end
  
  class Site
    attr_reader :path, :domain, :user, :realpath
    def initialize(path)
      @domain = File.basename(path)
      @path = path
      @realpath = Pathname.new(path).realpath
      if match = $user_directory.match(Pathname.new(path).realpath)
        @user = match[1].to_s
      end
      if @domain == 'htdocs'
        @domain = "#{@user}.#{$default_domain}"
      end
    end
  end
end
