#!/usr/bin/env ruby

#
# Written by Johan Eckerstr�m <johan@jage.se> 
# 
# 2007-05-22 - Stop using regexp for owner_map \
#               and improve syslog message
# 2006-12-19 - Compression for servers
# 2006-12-01 - External configuration file
# 2006-11-21 - Easier to change the user mapping regexp
# 2006-10-31 - Added syslog capabilities
# 2006-08-06 - First version
#
# Todo:
#  - Add regexp capabilities for the database-specifications
#  - Record elapsed time for backup

begin
  require 'fileutils'
  require 'syslog'
  require 'rubygems'
  require 'mysql'
rescue LoadError
  $stderr.puts 'Could not load required libraries'; exit 1
end

begin
  load '/etc/rmysqldump.conf'
rescue LoadError
  $stderr.puts 'Could not load configuration'; exit 1
end

$users = []
IO.foreach('/etc/passwd') do |line|
  $users << /(^[\w]+)/.match(line).to_s.strip
end

module MySQL
  class Databases

    attr_reader :list

    def initialize 
      @list = databases.collect {|i| Database.new(i) }
    end

    def failed
      @list.select {|i| i.fail }
    end

    def skipped
      @list.select {|i| i.skip }
    end

    def successes
      @list.select {|i| i.success }
    end

    private

    def databases
      list = []
      connection = Mysql.real_connect($server[:host], 
                                      $server[:user], 
                                      $server[:password])
      result = connection.query('SHOW DATABASES')
      result.each {|db| list << db.to_s }
      result.free
      list
    rescue Mysql::Error => error
      $stderr.puts error.message; exit 1
    end
  end

  class Database

    attr_reader :name, :lock, :owner, :group, :charset, :skip
    attr_accessor :success

    def initialize(name)
      @options = $database_options[name.to_sym] ||= Hash.new

      @name    = name
      @lock    = option_for(:lock)
      @owner   = option_for(:owner).to_s
      @group   = option_for(:group).to_s
      @charset = option_for(:charset).to_s
      @skip    = option_for(:skip)

      # Would be better if the database specific owner could override this
      if option_for(:map_owner) && owner = find_owner
        @owner = owner
      end
    end

    def to_s
      name
    end

    def path
      "#{$archive_dir}/#{self}.sql.gz"
    end

    def fail
      !success && !skip
    end

    private

    def option_for(key)
      @options[key] || $global_options[key] || false
    end

    def find_owner
        match = $users.select do |u|
          @name.include?(u) && u == @name[0...u.length]
        end

        if match.empty? 
          false
        else
          match.to_s
        end
    end
  end

  class Dump
    def initialize(databases)
      @databases = databases

      unless mysqldump_working?
        failure("Could not execute #{$mysqldump}"); exit 1
      end

      unless File.directory?($archive_dir)
        failure("Could not save in #{$archive_dir}"); exit 1
      end
    end

    def execute
      Syslog.open(ident='rmysqldump', facility=Syslog::LOG_DAEMON)
      @databases.list.each do |database|
        unless database.skip
          `#{$mysqldump} #{parameters_for(database)} #{database} | #{$gzip} > #{database.path}`
          failure("Could not dump #{database}") unless $?.success?
          begin
            FileUtils.chown database.owner, database.group, database.path
            FileUtils.chmod 0660, database.path
            database.success = true if $?.success?
          rescue => error
            failure("Could not set permissions: #{error.message}")
          end
        end
      end
      message  = "#{@databases.successes.length} databases dumped successfully"
      message += ", #{@databases.skipped.length} skipped" if @databases.skipped.length > 0
      Syslog.info(message)
      Syslog.err("#{@databases.failed.length} databases failed") if @databases.failed.length > 0
      Syslog.close
    end

    private

    def failure(message)
      $stderr.puts message
      Syslog.error(message) if Syslog.opened?
    end

    def mysqldump_working?
      File.readable?($mysqldump) and File.executable?($mysqldump)
    end

    def parameters_for(database)
      params   = "--default-character-set=#{database.charset} \
                  --user #{$server[:user]} \
                  --password=#{$server[:password]} \
                  --host #{$server[:host]}"
      params += " --compress" if $server[:compress]
      params += " --lock-tables" if database.lock
      params
    end
  end
end

MySQL::Dump.new(MySQL::Databases.new).execute
