#!/usr/bin/env ruby

require 'pathname'

module Phoo
  $default_domain = 'starkast.net'
  $default_ip     = '194.22.19.193'
  $user_home_directory = /^\/ustorage\/home\/([\w]+)(\/|$)/
  $user_www_directory = /^\/ustorage\/www\/users\/([\w]+)(\/|$)/
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
      @domain   = File.basename(path)
      @path     = path
      @realpath = Pathname.new(path).realpath
      @user     = Dir.user(path)
      if @domain == 'htdocs'
        @domain = "#{@user}.#{$default_domain}"
      end
    end
  end

  class Dir < Dir
    def self.user(path)
      path = Pathname.new(path).realpath
      m = ($user_www_directory.match(path) || $user_home_directory.match(path))
      m[1].to_s if m
    end
  end
end
