nvremind
========

A scheduled background task to scan nvALT notes for @reminder() tags and trigger notifications based on dates.

## Synopsis


This tool will search for @remind() tags in the specified notes folder.

It searches ".md" and ".txt" files.

It expects an ISO 8601 format date (2013-05-01) with optional 24-hour time (2013-05-01 15:30). Put `@remind(2013-05-01 06:00)` anywhere in a note to have a reminder go off on the first run after that time.

This script is intended to be run on a schedule. Check for reminders every 30-60 minutes using cron or launchd.

Use the -n option to send Mountain Lion notifications instead of terminal output. Clicking a notification will open the related file in nvALT. Notifications require that the 'terminal-notifier' gem be installed:

    sudo gem install 'terminal-notifier'


## Examples


        nvremind.rb ~/Dropbox/nvALT

Other examples:

        nvremind.rb -r ~/Dropbox/nvALT
        nvremind.rb -rn ~/Dropbox/nvALT


## Usage


      nvremind.rb [options] notes_folder

      For help use: nvremind.rb -h


## Options


      -h, --help          Displays help message
      -v, --version       Display the version, then exit
      -V, --verbose       Verbose output
      -r, --replace       Replace @remind() with @reminded() after notification
      -n, --notify        Use terminal-notifier to post Mountain Lion notifications


## Author


      Brett Terpstra


## Copyright


      Copyright (c) 2013 Brett Terpstra. Licensed under the MIT License:
      http://www.opensource.org/licenses/mit-license.php
