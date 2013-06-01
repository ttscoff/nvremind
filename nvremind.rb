#!/usr/bin/ruby
# == Synopsis
#   This tool will search for @remind() tags in the specified notes folder.
#
#   It searches ".md" and ".txt" files.
#
#   It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30).
#   Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run after that time.
#
#   This script is intended to be run on a schedule. Check for reminders every 30-60 minutes using cron or launchd.
#
#   Use the -n option to send Mountain Lion notifications instead of terminal output. Clicking a notification will open the related file in nvALT.
#   Notifications require that the 'terminal-notifier' gem be installed:
#
#   sudo gem install 'terminal-notifier'
#
# == Examples
#
#     nvremind.rb ~/Dropbox/nvALT
#
#   Other examples:
#     nvremind.rb -r ~/Dropbox/nvALT
#     nvremind.rb -rn ~/Dropbox/nvALT
#
# == Usage
#   nvremind.rb [options] notes_folder
#
#   For help use: nvremind.rb -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -V, --verbose       Verbose output
#   -r, --replace       Replace @remind() with @reminded() after notification
#   -n, --notify        Use terminal-notifier to post Mountain Lion notifications
#
# == Author
#   Brett Terpstra
#
# == Copyright
#   Copyright (c) 2013 Brett Terpstra. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php

require 'rdoc/usage'
require 'date'
require 'cgi'
require 'time'
require 'optparse'
require 'ostruct'

class Reminder
  VERSION = '0.0.1'

  attr_reader :options

  def initialize(arguments)
    @arguments = arguments

    @options = OpenStruct.new
    @options.remove = false
    @options.verbose = false
    @options.notify = false
  end

  def run
    if parsed_options? && arguments_valid?

      puts "Start at #{DateTime.now}\n\n" if @options.verbose

      output_options if @options.verbose # [Optional]

      process_arguments
      process_command

      puts "\nFinished at #{DateTime.now}" if @options.verbose

    else
      output_help
    end

  end

  protected

  def parsed_options?

    opts = OptionParser.new
    opts.on('-v', '--version')    { output_version ; exit 0 }
    opts.on('-h', '--help')       { output_help }
    opts.on('-V', '--verbose')    { @options.verbose = true }
    opts.on('-r', '--remove')     { @options.remove = true }
    opts.on('-n', '--notify')     { @options.notify = true }
    opts.parse!(@arguments) rescue return false

    true
  end

  def output_options
    puts "Options:\n"

    @options.marshal_dump.each do |name, val|
      puts "  #{name} = #{val}"
    end
  end

  def arguments_valid?
    true if @arguments[0] && File.exists?(File.expand_path(@arguments[0]))
  end

  def process_arguments
    @notes_dir = File.expand_path(@arguments[0])
    if @options.notify
      require 'rubygems'
      require 'terminal-notifier'
    end
  end

  def output_help
    output_version
    RDoc::usage() #exits app
  end

  def output_version
    puts "#{File.basename(__FILE__)} version #{VERSION}"
  end

  def process_command
    Dir.chdir(@notes_dir)
    file_list = %x{grep -El "@remind\(.*?\)" *.{md,txt}}.split("\n")
    file_list.each {|file|
      contents = IO.read(file)
      date_match = contents.match(/@remind\((.*?)\)/)
      unless date_match.nil?
        remind_date = Time.parse(date_match[1])
        if remind_date < Time.now
          message = "REMINDER: #{file} [#{remind_date.strftime('%F')}]"
          if @options.notify
            TerminalNotifier.notify(message, :title => "Reminder", :open => "nvalt://find/#{CGI.escape(File.basename(file).gsub(/\.(txt|md)$/,'')).gsub(/\+/,"%20")}")
          else
            puts message
          end
          if @options.remove
            File.open(file,'w+') do |f|
              f.puts contents.gsub(/@remind\(/,"@reminded(")
            end
          end
        end
      end
    }

  end

end

r = Reminder.new(ARGV)
r.run


