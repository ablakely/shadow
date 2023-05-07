# Shadow Perl IRC Bot

## What is shadow?
shadow is a modular IRC bot written in Perl by Aaron Blakely, it's goal is to be a stable IRC bot with cool featues.

## How do I install shadow?
  Just run installdepends, we'll do the rest! (Might need C libs or sudo depending on your system)

## Where can I get support for shadow?
  * Try irc.ephasic.org #shadow
  * `/msg bot help` 


# Installing
Installing Shadow is very simple thanks to our dependency installer, just run installdepends and let the script prepare your enviornment.  See below for specific instructuins related to your operating system.

## Linux
To install on debian/ubuntu systems you will need to following pakages:
`sudo apt-get install libjson-perl libxml-libxml-perl libxml-feed-perl build-essential`

## OS X
I've only tested on OS X 10.4 Tiger on my iMac G4.  To require the dependencies
for the RSS module you will need to install brew and run:
`brew install libxml2`

## Windows
To install on Windows, use [Strawberry Perl](https://strawberryperl.com) and [Git-bash](https://git-scm.com/download/win) for the shell.
  - Run installdepends.bat
  - Edit and rename your configuration (etc/shadow.conf.example -> etc/shadow.conf)
  - Run shadow.bat


# Standard Modules
* RSS.pm - RSS Feed Reader.
* AutoID.pm - Automatically authenticate with network services.
* ChanOP.pm - Basic channel management commands.
* Uptime.pm - Basic module which gives *nix uptime info (requires neofetch for Windows).
* Autojoin.pm - Automatically join channels on connect.
* URLIdentifier.pm - Automatically fetches the title of a URL.
* BotStats.pm - [Linux/Windows] Returns information about the bot, like memory usage.
* Fortune.pm - [*nix/Mac] Wrapper for the `fortune` command.
