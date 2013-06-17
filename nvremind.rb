#!/usr/bin/ruby
# == Synopsis
#   This tool will search for @remind() tags in the specified notes folder.
#
#   It searches ".md", ".txt", ".ft" and ".taskpaper" files. It also works with Day One journal folders.
#
#   It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30).
#   Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run after that time.
#
#
#   Reminders on their own line with no other text will send the entire note as the reminder with the filename being the subject line. If a @reminder tag is on a line with other text, only that line will be used as the title and the content.
#
#   If you include a double-quoted string at the end of the remind tag value, it will override the default reminder title. `@remind(2013-05-24 "This is the override")` would create a reminder called "This is the override", ignoring any other text on the line or the name of the file. Additional text on the line or the entire note (in the case of a @remind tag on its own line) will still be included in the note, if the notification method supports that.
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
#
#   The `-m` option will add a reminder to Reminders.app in Mountain Lion, due immediately, that will show up on iCloud-synced iOS devices as well.
# == Examples
#
#     nvremind.rb ~/Dropbox/nvALT
#
#   Other examples:
#     nvremind.rb ~/Dropbox/nvALT
#     nvremind.rb -n ~/Dropbox/nvALT
#     nvremind.rb -e me@gmail.com ~/Dropbox/nvALT
#     nvremind.rb -mn -e me@gmail.com ~/Dropbox/nvALT
# == Usage
#   nvremind.rb [options] notes_folder
#
#   For help use: nvremind.rb -h
#
#   See <http://brettterpstra.com/projects/nvremind> for more information
#
# == Options
#   -h, --help            Displays help message
#   -H                    No, really help
#   -v, --version         Display the version, then exit
#   -V, --verbose         Verbose output
#   -z, --no-replace      Don't updated @remind() tags with @reminded() after notification
#   -n, --notify          Use terminal-notifier to post Mountain Lion notifications
#   -m, --reminders       Add an item to the Reminders list in Reminders.app (due immediately)
#   --reminder-list LIST  List to use in Reminders.app (default "Reminders")
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

NVR_VERSION = '1.0.3'

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
  attr_reader :options

  def initialize(arguments)
    @arguments = arguments

    @options = OpenStruct.new
    @options.remove = true
    @options.verbose = false
    @options.notify = false
    @options.email = false
    @options.stdout = true
    @options.reminders = false
    @options.reminder_list = "Reminders"
  end

  def run
    if parsed_options? && arguments_valid?

      puts "Start at #{DateTime.now}\n\n" if @options.verbose

      output_options if @options.verbose # [Optional]

      process_arguments
      process_command

      puts "\nFinished at #{DateTime.now}" if @options.verbose

    else
      output_usage
    end

  end

  def e_as(str)
    str.to_s.gsub(/(?=["\\])/, '\\')
  end

  protected

  def parsed_options?

    opts = OptionParser.new
    opts.on('-v', '--version')      { output_version ; exit 0 }
    opts.on('-h', '--help')         { output_help }
    opts.on('-H')                   { output_long_help }
    opts.on('-V', '--verbose')      { @options.verbose = true }
    opts.on('-z', '--no-replace')   { @options.remove = false }
    opts.on('-n', '--notify')       { @options.notify = true }
    opts.on('-r', '--replace')      {  } # depricated, backward compatibility only
    opts.on('-m', '--reminders')    { @options.reminders = true }
    opts.on('--reminder-list LIST') { |list| @options.reminder_list = list }
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
    @notes_dir = []
    @arguments[0].split(",").each {|path|
      @notes_dir.push(File.expand_path(path)) if File.exists?(File.expand_path(path))
    }
    true unless @notes_dir.empty?
  end

  def process_arguments

    if @options.notify
      begin
        require 'rubygems'
        gem 'terminal-notifier', '>=1.4'
        require 'terminal-notifier'
        @options.notify = "terminal-notifier"
      rescue Gem::LoadError
        @options.notify = %x{growlnotify &>/dev/null && echo $? || echo false}.strip == "0" ? "growlnotify" : false
        $stderr.puts "Either terminal-notifier gem or growlnotify must be installed to use Notifications" unless @options.notify
      end
    end
    if (@options.notify || @options.email || @options.reminders) && !@options.verbose
      @options.stdout = false
    end
  end

  def output_usage
    output_version
    RDoc::usage("Usage") #exits app
  end

  def output_help
    output_version
    RDoc::usage("Options")
  end

  def output_long_help
    output_version
    RDoc::usage
  end

  def output_version
    puts "#{File.basename(__FILE__)} version #{NVR_VERSION}"
  end

  def process_command
    @notes_dir.each {|notes_dir|

      Dir.chdir(notes_dir)

      %x{grep -El "[^\s]remind\(.*?\)" *.{md,txt,taskpaper,ft,doentry} 2>/dev/null}.split("\n").each {|file|
        input = IO.read(file)
        lines = input.split(/\n/)
        counter = 0
        lines.map! {|contents|
          counter += 1
          # don't remind if the line contains @done or @canceled
          unless contents =~ /\s@(done|cancell?ed)/
            date_match = contents.match(/([^\s"`'\(\[])remind\((.*)(\s"(.*?)")?\)/)
            unless date_match.nil?
              remind_date = Time.parse(date_match[2])

              if remind_date <= Time.now
                stripped_line = contents.gsub(/["`'\(\[]?#{Regexp.escape(date_match[0])}["`'\)\]]?\s*/,'').gsub(/<\/?string>/,'').strip
                # remove leading - or * in case it's in a TaskPaper or Markdown list
                stripped_line.sub!(/^[\-\*\+] /,"")
                filename = "#{notes_dir}/#{file}".gsub(/\+/,"%20")
                is_day_one = File.extname(file) =~ /doentry$/
                if is_day_one
                  xml = IO.read(file)
                  dayone_content = xml.match(/<key>Entry Text<\/key>\s*<string>(.*?)<\/string>/m)[1]
                  if dayone_content
                    note_title = dayone_content.split(/\n/)[0].gsub(/[#<>\-\*\+]/,"")[0..30].strip
                  else
                    note_title = "From Day One"
                  end
                else
                  note_title = File.basename(file).gsub(/\.(txt|md|taskpaper|ft|doentry)$/,'')
                end
                if stripped_line == ""
                  @title = date_match[4] || note_title
                  @extension = File.extname(file)
                  @message = "#{@title} [#{remind_date.strftime('%F')}]"
                  @note = is_day_one ? dayone_content : IO.read(file)
                  if @extension =~ /(md|txt)$/
                     @note += "\n\n- <nvalt://find/#{CGI.escape(note_title).gsub(/\+/,"%20")}>\n"
                  end
                else
                  @title = date_match[4] || stripped_line
                  @extension = ""
                  @message = "#{@title} [#{remind_date.strftime('%F')}]"
                  # add :#{counter} after #{filename} to include line number below
                  if is_day_one
                    @note = stripped_line
                  else
                    @note = "#{stripped_line}\n\n- file://#{filename}\n- nvalt://find/#{CGI.escape(note_title).gsub(/\+/,"%20")}\n"
                  end
                end
                if @options.verbose
                  puts "Title: #{@title}"
                  puts "Extension: #{@extension}"
                  puts "Message: #{@message}"
                  puts "Note: #{@note}"
                end
                notify
                if @options.remove
                  contents.gsub!(/([^\s"`'\(\[])remind\((.*?)(\s"(.*?)")?\)/) do |match|
                    if Time.parse($2) < Time.now
                      "#{$1}reminded(#{Time.now.strftime('%Y-%m-%d %H:%M')}#{$3})"
                    else
                      match
                    end
                  end
                end
              end
            end
          end
          contents
        }
        File.open(file,'w+') do |f|
          f.puts lines.join("\n")
        end
      }
    }
  end

  def notify
    if @options.stdout
    puts @message
    end
    if @options.notify == "terminal-notifier"
      TerminalNotifier.notify(@message, :title => "Reminder", :open => "nvalt://find/#{CGI.escape(@title).gsub(/\+/,"%20")}")
    elsif @options.notify == "growlnotify"
      %x{growlnotify -m "#{@message}" -t "Reminder" -s}
    end
    if @options.reminders
      %x{osascript <<'APPLESCRIPT'
        tell application "Reminders"
        if name of lists does not contain "#{@options.reminder_list}" then
          set _reminders to item 1 of lists
        else
          set _reminders to list "#{@options.reminder_list}"
        end if
        set d to ((current date) + 120)
        make new reminder at end of _reminders with properties {name:"#{@title}", remind me date:d, body:"#{e_as(@note)}"}
      end tell
    APPLESCRIPT}
    end
    if @options.email
      subject = @title
      content = @note
      if @extension == ".taskpaper"
        if File.exists?("/usr/local/bin/multimarkdown")
          md = "format: complete\n\n#{TaskPaper.new.tp2md(@note)}"
          content = %x{echo #{Shellwords.escape(md)}|/usr/local/bin/multimarkdown}
        end
      else
        if File.exists?("/usr/local/bin/multimarkdown")
          content = %x{echo #{Shellwords.escape("format: complete\n\n" + @note)}|/usr/local/bin/multimarkdown}
        end
      end
      template =<<ENDTEMPLATE
Subject: #{@title}
From: nvreminder@system.net
MIME-Version: 1.0
Content-Type: text/html;

#{content}

ENDTEMPLATE
      @options.email.each {|email|
        %x{echo #{Shellwords.escape(template)}|/usr/sbin/sendmail #{email}}
      }
    end
  end
end

r = Reminder.new(ARGV)
r.run



