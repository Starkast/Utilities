#!/usr/local/bin/ruby

require File.expand_path('../../lib/phoo.rb', __FILE__)
require 'yaml'
require 'erb'

# TODO
# - Rescue for files

## Settings
$database     = '/var/www/db/sites'
$template     = '/usr/local/share/Starkast-Utilities/nginx_user_template.erb'
$user_index   = '/etc/nginx/users/index'
$user_configs = '/etc/nginx/users/*.conf'
$sites_html   = '/var/www/htdocs/sites.html'
$sites_template = '/etc/Starkast-Utilities/sites.erb'

module Phoo
  class NginxGenerator
    def initialize
      load_config
      generate
      create_stats
    rescue => e
      $stderr.puts e; exit 1
    end
 
    def load_config
      @data = YAML.load($stdin.read)

      @use_apache = false
      if @data and @data['use_apache']
        @use_apache = true
      end

      @php_procs = 2
      if @data and @data['php_procs']
        @php_procs = @data['php_procs'].to_i
        @php_disabled = (@php_procs == 0)
      end

      if not @data or not @data['sites']
         @data = {'sites' => {}}
      end
    end
    
    def site_directories
      Dir.glob("/var/www/users/#{user}/vhosts/*").collect do |directory|
        begin
          next if not File.directory?(directory)
          File.basename(directory)
        rescue Errno::ENOENT
          next
        end
      end.compact
    end
    

    def generate
      # Load database
      if File.exist?($database)
        db_sites = Marshal.load(File.read($database)) || {}
      else
        db_sites = {}
      end

      # Make sure the default htdocs is there
      # XXX ugly!
      unless @data['sites'].include?('default') or 
        @data['sites'].include?("#{user}.starkast.net")
        @data['sites']['default'] = {}
      end

      # Make sure all sites are noticed, even those not in the config
      site_directories.each do |site|
        unless @data['sites'][site]
          @data['sites'][site] = {}
        end
      end
      
      # Create Site-objects for @sites
      @sites = {}
      @data['sites'].each do |name, hash|
        site = Site.new(name, hash)
        @sites[site.name] = site
      end
      
      # Check for domains that are busy by other or by the user
      @sites.each do |name, site|
        if db_sites[name]          
          if site.server_name.split(' ') & db_sites[name].server_name.split(' ') and user != db_sites[name].user
            @sites.delete(name)
            @data['sites'].delete(name)
            puts "#{site.server_name.split.first} is owned by someone else, skipped"
            next
          end
        end
        db_sites[name] = site
      end

      # Find old sites
      db_sites.each do |name, site|
        if site.user == user and not @sites[name]
          db_sites.delete name
        end
      end

      domains = Hash.new([])
      @sites.each do |name, site|
        user = site.user
        hosts = site.server_name.split(' ')
        # if host has been used
        duplicate = domains[user] & hosts
        if not duplicate.empty?
          $stderr.puts "#{duplicate.first} is a duplicate! Check your config" 
        end
        domains[user] = domains[user] | hosts
      end
      
      # Create upstream Hash
      @upstreams = {}
      @sites.each do |name, site|
        if not site.upstreams.empty?
          # Make sure upstreams is an array
          @upstreams[name] = ([] << site.upstreams).flatten
        end
      end
      
      # Save Database
      File.open($database, 'w') do |fp|
        fp.print Marshal.dump(db_sites)
      end
      
      # Save Config
      File.open("/etc/nginx/users/#{user}.conf", 'w') do |fp|
        fp.print ERB.new(File.read($template), nil, '>').result(binding)
      end

      # Update Index
      File.open($user_index, 'w') do |fp|
        Dir.glob($user_configs) do |u|
          fp.puts "include #{u};"
        end
      end
    rescue => e
      $stderr.puts e; exit 1
    end

    def create_stats
      sites = Marshal.load(File.read($database))
      sites.delete_if { |key, i| i.hidden }
      sites = sites.collect do |key, site|
        key
      end
      sites.sort!

      File.open($sites_html, 'w') do |fp|
        fp.print ERB.new(File.read($sites_template), nil, '>').result(binding)
      end
    end
    
    def user
      @user ||= (ENV['WEBCTL_USER'] || ENV['SUDO_USER'] || `whoami`).strip
    end
  end
  
  class Site
    
    attr_reader :name, :upstreams, :no_www, :use_apache,
      :always_www, :auth_file, :rewrites, :autoindex,
      :upstreams_exclude, :default_mime, :hidden, :fastcgi,
      :passenger, :rails_env
    
    def initialize(name, hash = {})
      @hash = (hash ||= {})

      if name == 'default'
        @name = "#{user}.starkast.net"
      else
        @name = name
      end

      @upstreams_exclude = hash['upstream_exclude'] || 
                           hash['upstream_excludes'] || []
      @upstreams    = hash['upstream']     || hash['upstreams'] || []
      @fastcgi      = hash['fastcgi']      || false
      @use_apache   = hash['use_apache']   || false
      @no_www       = hash['no_www']       || false
      @always_www   = hash['always_www']   || false
      @auth_file    = hash['auth_file']    || false
      @default_mime = hash['default_mime'] || false
      @rewrites     = ([] << hash['rewrite']).flatten || hash['rewrites'] || []
      @autoindex    = hash['autoindex'] == false ? false : true # Default to true
      @hidden       = hash['hidden']       || false
      @passenger    = hash['passenger']    || false
      @rails_env    = hash['rails_env']    || false
    rescue => e
      $stderr.puts e; exit 1
    end

    def server_name
      names = []
      if @hash['alias'] and not @hash['alias'].empty?
        names = @hash['alias'].split(' ')
      end
      # Backwards compability
      if @hash['server_name'] and not @hash['server_name'].empty?
        names = @hash['server_name'].split(' ')
      end
      if default_host?
        names = [default_server_name]
      else
        names << self.name unless default_host?
      end
      names.uniq!
      names.collect! do |host|
        "#{host} www.#{host}"
      end
      names.join(' ')
    end
    
    def user
      @user ||= (ENV['WEBCTL_USER'] || ENV['SUDO_USER'] || `whoami`).strip
    end

    def root
      if default_host?
        "/var/www/users/#{user}/htdocs"
      else
        if @passenger
          "/var/www/users/#{user}/webapps/#{name}/public"
        else
          "/var/www/users/#{user}/vhosts/#{name}"
        end
      end
    end

  private

    def default_host?
      self.name == 'default' or self.name == "#{user}.starkast.net"
    end

    def default_server_name
      if default_host?
        "#{user}.starkast.net"
      else
        self.name
      end
    end

  end
end

Phoo::NginxGenerator.new
