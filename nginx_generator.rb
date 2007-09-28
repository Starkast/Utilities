#!/usr/local/bin/ruby

require '/opt/lib/phoo.rb'
require 'yaml'
require 'erb'

# TODO
# - Check /var/www/vhosts
# - Rescue for files

## Settings
$database = '/var/www/db/sites'

module Phoo  
  class NginxGenerator
    def initialize
      load_config
      generate
    rescue => e
      $stderr.puts e; exit 1
    end
 
    def load_config
      @data = YAML.load($stdin.read)

      @use_apache = false
      if @data and @data['use_apache']
        @use_apache = true
      end

      @use_php = false
      if @data and @data['use_php']
        @use_php = true
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
      @user = user

      # Load database
      if File.exist?($database)
        db_sites = Marshal.load(File.open($database) {|fp| fp.read }) || {}
      else
        db_sites = {}
      end

      # Make sure the default htdocs is there
      unless @data['sites'].include?('default')
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
          if site.server_name.split(' ') & db_sites[name].server_name.split(' ') and self.user != db_sites[name].user
            @sites.delete(name)
            @data['sites'].delete(name)
            puts "#{site.server_name.split.first} is owned by someone else, skipped"
            next
          end
        end
        db_sites[name] = site
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
          @upstreams[name] = site.upstreams
        end
      end
      
      # Save Database
      File.open($database, 'w') do |fp|
        fp.print Marshal.dump(db_sites)
      end
      
      # Save Config
      File.open("/etc/nginx/users/#{user}.conf", 'w') do |fp|
        fp.print ERB.new(File.read(template), nil, '>').result(binding)
      end

      # Update Index
      File.open("/etc/nginx/users/index", 'w') do |fp|
        Dir.glob("/etc/nginx/users/*.conf") do |u|
          fp.puts "include #{u};"
        end
      end
    rescue => e
      $stderr.puts e; exit 1
    end
    
    def template
      "/etc/nginx/user_template.erb"
    end

    def user
      (ENV['WEBCTL_USER'] || ENV['SUDO_USER'] || `whoami`).strip
    end
  end
  
  class Site
    
    attr_reader :name, :upstreams, :no_www, :use_apache,
      :always_www, :auth_file, :rewrites,
      :upstreams_exclude, :default_mime
    
    def initialize(name, hash)
      @hash = hash || {}

      if name == 'default'
        @name = "#{user}.starkast.net"
      else
        @name = name
      end
      @upstreams   = hash['upstream']    || hash['upstreams'] || []
      @upstreams_exclude = hash['upstream_exclude'] || 
                           hash['upstream_excludes'] || []
      @use_apache  = hash['use_apache']  || false
      @no_www      = hash['no_www']      || false
      @always_www  = hash['always_www']  || false
      @auth_file   = hash['auth_file']   || false
      @default_mime= hash['default_mime'] || false
      @rewrites    = hash['rewrite']     || hash['rewrites'] || []
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
      (ENV['SUDO_USER'] || ENV['WEBCTL_USER'] || `whoami`).strip
    end

    def root
      if default_host?
        "/var/www/users/#{user}/htdocs"
      else
        "/var/www/users/#{user}/vhosts/#{name}"
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
