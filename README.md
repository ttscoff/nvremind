nvremind
========

A scheduled background task to scan nvALT notes for @remind() tags and trigger notifications based on dates. It's grown to work with any folder of text or Markdown files, TaskPaper files and [Day One](http://dayoneapp.com/) entries.

Yes, it's pronounced "never mind."

## Synopsis


This tool will search for @remind() tags in the specified notes folder.

It searches ".md", ".txt", ".ft", ".taskpaper" and Day One entry files.

It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30). Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run following that time.

This script is intended to be run on a schedule. Check for reminders every 30-60 minutes using cron or launchd.

By default the script will replace found @remind tags with @reminded tags containing the date the reminder was sent. Use the `-z` option to prevent any changes from being made to your file, although this can result in reminders being sent multiple times. You'd need to manually update the files after handling the reminder.

The script also preserves the original modification time of the file. To instead update the modification time to the date when it was matched, use `--no-preserve-time`.

A document can contain multiple reminders with different dates. The script will check all of them and only modify the ones that are triggered. Future reminders in the same document will still be active after the run.

Reminders on their own line with no other text will send the entire note as the reminder with the filename being the subject line. If a @remind tag is on a line with other text, only that line will be used as the title and the content.

If you include a double-quoted string at the end of the remind tag value, it will override the default reminder title. `@remind(2013-05-24 "This is the override")` would create a reminder called "This is the override", ignoring any other text on the line or the name of the file. Additional text on the line or the entire note (in the case of a @remind tag on its own line) will still be included in the note, if the notification method supports that.

Use the `-n` option to send Mountain Lion notifications instead of terminal output. Clicking a notification will open the related file in nvALT. Notifications require that the 'terminal-notifier' gem be installed (falls back to [growlnotify](http://growl.info/downloads#generaldownloads) if it exists):

    sudo gem install 'terminal-notifier'

Use the `-e ADDRESS` option to send an email with the title of the note as the subject and the contents of the note as the body to the specified address. Separate multiple emails with commas. The contents of the note will be rendered with MultiMarkdown, which needs to exist at `/usr/local/bin/multimarkdown`. 

If the file to be emailed has a ".taskpaper" extension, it will be converted to Markdown for formatting before processing with MultiMarkdown. [[Links]] and @tags will be linked and can be clicked from Mail.app.

The `-m` option will add a reminder to Reminders.app in Mountain Lion, due immediately, that will show up on iCloud-synced iOS devices as well. Specify a list (default "Reminders" or the first list available) using `--reminder-list "List name"`.

The `-f FOLDER` option allows you to specify a directory where a file named with the reminder title will be saved. The note for the reminder will be the file contents. This is useful, for example, with IFTTT.com. You can save a file to a public Dropbox folder, have IFTTT notice it and take any number of actions on it.

## Examples


    nvremind.rb ~/Dropbox/nvALT

Other examples:

    nvremind.rb ~/Dropbox/nvALT
    nvremind.rb -n ~/Dropbox/nvALT
    nvremind.rb -e me@gmail.com ~/Dropbox/nvALT
    nvremind.rb -mn -e me@gmail.com ~/Dropbox/nvALT
    nvremind.rb -f ~/Dropbox/Public/ifttt ~/Dropbox/nvALT

Testing/debugging example:

    nvremind.rb -Vz ~/Dropbox/nvALT

## Usage


    nvremind.rb [options] notes_folder

For help use `nvremind.rb -h`. For even more help, use `nvremind.rb -H`.


## Options


    -h, --help            Displays help message
    -H                    No, really help
    -v, --version         Display the version, then exit
    -V, --verbose         Verbose output
    -z, --no-replace      Don't updated @remind() tags with @reminded() after notification
    -n, --notify          Use terminal-notifier to post Mountain Lion notifications
    -m, --reminders       Add an item to the Reminders list in Reminders.app (due immediately)
    --reminder-list LIST  List to use in Reminders.app (default "Reminders")
    -f folder             Save a file to FOLDER named with the task title, note as contents
    -e EMAIL[,EMAIL], --email EMAIL[,EMAIL] Send an email with note contents to the specified address

## Changelog

### 1.0.6

* Fixed UTF-8 and Ruby 2.0 issues
* Added File notification method for use with IFTTT, etc.

### 1.0

* Works with any prefix, not just "@". To allow use in apps like Day One that have different uses for @tags. Any character will work (!remind, $remind), there just has to be something immediately before "remind"
* Works with multiple paths, just separate with commas (no space)
* Works with Day One, just pass it the path to the entries folder within your Journal
    * In Day One, if a reminder is on its own line and has no override title, the first 30 characters of the first line of the entry will be used as the reminder title.
        
        This is necessary because Day One entries don't have titles and the filenames are just UUID strings.
* If the tag is inside of quotes or brackets, those will be stripped from the reminder title
* If you include a double-quoted string at the end of the remind tag value, it will override the default reminder title. @reminded(2013-06-06 09:52 "This is the override") would create a reminder called "This is the override", ignoring any other text on the line or the name of the file. 
        
        Additional text on the line or the entire note (in the case of a @remind tag on its own line) will still be included in the note, if the notification method supports that.
* You can specify a list for Reminders.app (default "Reminders" or the first list available) using '--reminder-list "List name"'
* Won't schedule the reminder if the same line contains @done or @canceled (also recognizes @cancelled)
* Remove leading -, * or + so you can use it within Markdown lists and still get nicely-formatted reminder messages
* Don't include line number in file link (that just breaks it for 90% of the population)
* Use a remind date 1 minute in the future to allow iOS notifications when using Reminders.app
* Allows multiple target folders in the last argument, separated by commas (no spaces)

### 0.2.2

- Allow title override with double quoted string at end of tag
- Allow specification of an alternate Reminders.app list (`--reminder-list LIST`)
- Remove list markers from captured line notes
- Remove line number from file link

### 0.2.1

- Add FoldingText extension
- Handle multiple reminders per file

### 0.2.0

- Reminders.app integration

## Author


Brett Terpstra


## Copyright

Copyright (c) 2013 Brett Terpstra. Licensed under the MIT License:  
<http://www.opensource.org/licenses/mit-license.php>
