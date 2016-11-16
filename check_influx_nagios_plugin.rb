#!/usr/bin/env ruby

require 'rubygems'
require 'mixlib/cli'
require 'yaml'
require 'influxdb'
require 'date'

class MyCLI
  include Mixlib::CLI

  option :config_file,
    :short => "-c CONFIG",
    :long  => "--config CONFIG",
    :default => '/root/.influx',
    :description => "The configuration file to connect to your influxDB"

  option :warning,
    :short => "-w FLOAT",
    :long  => "--warning FLOAT",
    :description => "Set the warning value for your check",
    :required => true,
    :proc => Proc.new { |l| l.to_f }

  option :critical,
    :short => "-c FLOAT",
    :long  => "--critical FLOAT",
    :description => "Set the critical value for your check",
    :required => true,
    :proc => Proc.new { |l| l.to_f }

  option :sql,
    :short => "-s 'SQL-QUERY'",
    :long  => "--sql 'SQL-QUERY'",
    :description => "Sql query returned your value",
    :required => true

  option :invert,
    :short => "-i",
    :long => "--invert",
    :description => "Invert result calculation ",
    :on => :tail,
    :boolean => true,
    :default => false

  option :expired,
    :short => "-e NUMBER",
    :long => "--expired NUMBER",
    :description => "Time of expired, if result time plus NUMBER more than now get CRITICAL status",
    :proc => Proc.new { |l| l.to_s },
    :default => false

  option :help,
    :short => "-h",
    :long => "--help",
    :description => "Show this message",
    :on => :tail,
    :boolean => true,
    :show_options => true,
    :exit => 0

end

cli = MyCLI.new
cli.parse_options
config = cli.config[:config_file] # 'foo.rb'
warning = cli.config[:warning]
critical = cli.config[:critical]
sql = cli.config[:sql]
invert = cli.config[:invert]
expired = cli.config[:expired]

status = 0
status_txt = 'None'
description = 'empty'


begin
 cnf = YAML::load(File.open(config))
rescue
 puts "config file #{config} invalid"
 exit
end



influxdb = InfluxDB::Client.new cnf['database'],
  username: cnf['username'],
  password: cnf['password'],
  host: cnf['server']


tmp_hash = nil
influxdb.query sql do |name, tags, points|
  tmp_hash = points[0]
end

if tmp_hash.nil?
puts "CRITICAL; empty result, sql:#{sql}"
exit 2
end


time = tmp_hash.delete('time')

time_parsed = DateTime.parse(time)

value = nil

tmp_hash.each{|key,val| value = val.to_f }



if invert
  if value < warning
    status = 1
    description = " value:#{value} < #{warning}(warning) "
  end
  if value < critical
    status = 2
    description = " value:#{value} < #{critical}(critical) "
  end
else

  if value > warning
    status = 1
    description = " value:#{value} > #{warning}(warning) "
  end
  if value > critical
    status = 2
    description = " value:#{value} > #{critical}(critical) "
  end
end

description = "value:#{value}" if status == 0

if expired.to_i > 0
   e = expired.to_i
   if time_parsed.to_time.to_i + e < Time.now.to_i
     status = 2
     description = "time too old,time: #{time}, value:#{value}"
   end
end

case status
when 0
  status_txt = 'OK'
when 1
  status_txt = 'WARNING'
when 2
  status_txt = 'CRITICAL'
when 3
  status_txt = 'UNKNOWN'
end

puts "#{status_txt},#{description},sql:#{sql}"

exit status
