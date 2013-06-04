nvremind
========

A scheduled background task to scan nvALT notes for @reminder() tags and trigger notifications based on dates.

## Synopsis


This tool will search for @remind() tags in the specified notes folder.

It searches ".md" and ".txt" files.

It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30). Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run after that time.

This script is intended to be run on a schedule. Check for reminders every 30-60 minutes using cron or launchd.

By default the script will replace found @remind tags with @reminded tags containing the date the reminder was sent. Use the `-z` option to prevent any changes from being made to your file, although this can result in reminders being sent multiple times. You'd need to manually update the files after handling the reminder.

A document can contain multiple reminders with different dates. The script will check all of them and only modify the ones that are triggered. Future reminders in the same document will still be active after the run.

Reminders on their own line with no other text will send the entire note as the reminder with the filename being the subject line. If a @reminder tag is on a line with other text, only that line will be used as the title and the content.

If you include a double-quoted string at the end of the remind tag value, it will override the default reminder title. `@remind(2013-05-24 "This is the override")` would create a reminder called "This is the override", ignoring any other text on the line or the name of the file. Additional text on the line or the entire note (in the case of a @remind tag on its own line) will still be included in the note, if the notification method supports that.

Use the `-n` option to send Mountain Lion notifications instead of terminal output. Clicking a notification will open the related file in nvALT. Notifications require that the 'terminal-notifier' gem be installed:

    sudo gem install 'terminal-notifier'

Use the `-e ADDRESS` option to send an email with the title of the note as the subject and the contents of the note as the body to the specified address. Separate multiple emails with commas. The contents of the note will be rendered with MultiMarkdown, which needs to exist at `/usr/local/bin/multimarkdown`. 

If the file to be emailed has a ".taskpaper" extension, it will be converted to Markdown for formatting before processing with MultiMarkdown. [[Links]] and @tags will be linked and can be clicked from Mail.app.

The `-m` option will add a reminder to Reminders.app in Mountain Lion, due immediately, that will show up on iCloud-synced iOS devices as well. Specify a specific list (default "Reminders" or the first list available) using `--reminder-list "List name"`.

## Examples


    nvremind.rb ~/Dropbox/nvALT

Other examples:

    nvremind.rb ~/Dropbox/nvALT
    nvremind.rb -n ~/Dropbox/nvALT
    nvremind.rb -e me@gmail.com ~/Dropbox/nvALT
    nvremind.rb -mn -e me@gmail.com ~/Dropbox/nvALT

Testing/debugging example:

    nvremind.rb -Vz ~/Dropbox/nvALT

## Usage


    nvremind.rb [options] notes_folder

For help use `nvremind.rb -h`. For even more help, use `nvremind.rb -H`.


## Options


    -h, --help          Displays help message
    -H                  No, really help
    -v, --version       Display the version, then exit
    -V, --verbose       Verbose output
    -z, --no-replace    Don't replace @remind() with @reminded() after notification
    -n, --notify        Use terminal-notifier to post Mountain Lion notifications
    -m, --reminders     Add an item to the Reminders list in Reminders.app (due immediately)
    -e EMAIL[,EMAIL], --email EMAIL[,EMAIL] Send an email with note contents to the specified address

## Changelog

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
