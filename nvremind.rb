#!/usr/bin/ruby
# == Synopsis
#   This tool will search for @remind() tags in the specified notes folder.
#
#   It searches ".md", ".txt" and ".taskpaper" files.
#
#   It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30).
#   Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run after that time.
#
#   This script is intended to be run on a schedule. Check for reminders every 30-60 minutes using cron or launchd.
#
#   Use the -n option to send Mountain Lion notifications instead of terminal output. Clicking a notification will open the related file in nvALT.
#   Notifications require that the 'terminal-notifier' gem be installed:
#
#       sudo gem install 'terminal-notifier'
#
#   Use the -e ADDRESS option to send an email with the title of the note as the subject and the contents of the note as the body to the specified address. Separate multiple emails with commas. The contents of the note will be rendered with MultiMarkdown, which needs to exist at /usr/local/bin/multimarkdown.
#
#   If the file has a ".taskpaper" extension, it will be converted to Markdown for formatting before processing with MultiMarkdown.
# == Examples
#
#     nvremind.rb ~/Dropbox/nvALT
#
#   Other examples:
#     nvremind.rb -r ~/Dropbox/nvALT
#     nvremind.rb -rn ~/Dropbox/nvALT
#     nvremind.rb -r -e me@gmail.com ~/Dropbox/nvALT
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
#   -z, --no-replace    Don't updated @remind() tags with @reminded() after notification
#   -n, --notify        Use terminal-notifier to post Mountain Lion notifications
#   -e EMAIL[,EMAIL], --email EMAIL[,EMAIL] Send an email with note contents to the specified address
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
require 'shellwords'

class TaskPaper
  def tp2md(input)
    header = input.scan(/Format\: .*$/)
    output = ""
    prevlevel = 0
    begin
        input.split("\n").each {|line|
          if line =~ /^(\t+)?(.*?):(\s(.*?))?$/
            tabs = $1
            project = $2
            if tabs.nil?
              output += "\n## #{project} ##\n\n"
              prevlevel = 0
            else
              output += "#{tabs.gsub(/^\t/,"")}* **#{project.gsub(/^\s*-\s*/,'')}**\n"
              prevlevel = tabs.length
            end
          elsif line =~ /^(\t+)?\- (.*)$/
            task = $2
            tabs = $1.nil? ? '' : $1
            task = "*<del>#{task}</del>*" if task =~ /@done/
            if tabs.length - prevlevel > 1
              tabs = "\t"
              prevlevel.times {|i| tabs += "\t"}
            end
            tabs = '' if prevlevel == 0 && tabs.length > 1
            output += "#{tabs.gsub(/^\t/,'')}* #{task.strip}\n"
            prevlevel = tabs.length
          else
            next if line =~ /^\s*$/
            tabs = ""
            (prevlevel - 1).times {|i| tabs += "\t"}
            output += "\n#{tabs}*#{line.strip}*\n"
          end
        }
    rescue => err
        puts "Exception: #{err}"
        err
    end
    o = ""
    o += header.join("\n") + "\n" unless header.nil?
    o += "<style>.tag strong {font-weight:normal;color:#555} .tag a {text-decoration:none;border:none;color:#777}</style>"
    o += output.gsub(/\[\[(.*?)\]\]/,"<a href=\"nvalt://find/\\1\">\\1</a>").gsub(/(@[^ \n\r\(]+)((\()([^\)]+)(\)))?/,"<em class=\"tag\"><a href=\"nvalt://find/\\0\">\\1\\3<strong>\\4</strong>\\5</a></em>")
    o
  end
end

class Reminder
  VERSION = '0.0.1'

  attr_reader :options

  def initialize(arguments)
    @arguments = arguments

    @options = OpenStruct.new
    @options.remove = true
    @options.verbose = false
    @options.notify = false
    @options.email = false
    @options.stdout = true
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
    opts.on('-z', '--no-replace') { @options.remove = false }
    opts.on('-n', '--notify')     { @options.notify = true }
    opts.on('-r', '--replace')    {  } # depricated, backward compatibility only
    opts.on('-e EMAIL[,EMAIL]', '--email EMAIL[,EMAIL]') { |emails|
      @options.email = []
      emails.split(/,/).each {|email|
        @options.email.push(email.strip)
      }
    }
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
    if (@options.notify || @options.email) && !@options.verbose
      @options.stdout = false
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
    file_list = %x{grep -El "@remind\(.*?\)" *.{md,txt,taskpaper}}.split("\n")
    file_list.each {|file|
      contents = IO.read(file)
      date_match = contents.match(/@remind\((.*?)\)/)
      unless date_match.nil?
        remind_date = Time.parse(date_match[1])
        if remind_date < Time.now
          message = "REMINDER: #{file} [#{remind_date.strftime('%F')}]"
          if @options.stdout
            puts message
          end
          if @options.notify
            TerminalNotifier.notify(message, :title => "Reminder", :open => "nvalt://find/#{CGI.escape(File.basename(file).gsub(/\.(txt|md|taskpaper)$/,'')).gsub(/\+/,"%20")}")
          end
          if @options.email
            subject = File.basename(file).gsub(/\.(txt|md|taskpaper)$/,'')
            if File.extname(file) == ".taskpaper"
              md = "format: complete\n\n#{TaskPaper.new.tp2md(IO.read(file))}"
              content = %x{echo #{Shellwords.escape(md)}|/usr/local/bin/multimarkdown}
            else
              content = %x{echo "format: complete\n\n" | cat - "#{file}"|/usr/local/bin/multimarkdown}
            end
            template =<<ENDTEMPLATE
Subject: #{subject}
From: nvreminder@system.net
MIME-Version: 1.0
Content-Type: text/html;

#{content}

ENDTEMPLATE
            @options.email.each {|email|
              %x{echo #{Shellwords.escape(template)}|/usr/sbin/sendmail #{email}}
            }
          end
          if @options.remove
            contents.gsub!(/@remind\((.*?)\)/) {|match|
              date = match.match(/\((.*?)\)/)[1]
              remind_date = Time.parse(date)
              if remind_date < Time.now
                "@reminded(#{Time.now.strftime('%Y-%m-%d %H:%M')})"
              else
                match
              end
            }

            File.open(file,'w+') do |f|
              f.puts contents
            end
          end
        end
      end
    }

  end

end

r = Reminder.new(ARGV)
r.run


