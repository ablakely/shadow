# Shadow Perl IRC Bot
  Written by Aaron Blakely

## What is shadow?
  shadow is a modular IRC bot written in Perl,
  it's goal is to be a stable IRC bot with cool featues.

## How do I install shadow?
  Just run installdepends.pl, we'll do the rest! (Might need C libs or sudo depending on your system)

## Where can I get support for shadow?
  * Try irc.alphachat.net #ephasic
  * `/msg bot help` 

---
## Installing
To install on debian/ubuntu systems you will need to following pakages:
`sudo apt-get install libjson-perl libxml-libxml-perl build-essential`

# OS X
I've only tested on OS X 10.4 Tiger on my iMac G4.  To require the dependencies
for the RSS module you will need to install brew and run:
`brew install libxml2`

## Standard Modules
* RSS.pm - RSS Feed Reader.
* AutoID.pm - Automatically authenticate with network services.
* ChanOP.pm - Basic channel management commands.
* Uptime.pm - Basic module which gives *nix uptime info
* Autojoin.pm - Automatically join channels on connect.
* URLIdentifier.pm - Automatically fetches the title of a URL.
* BotStats.pm - [Linux] Returns information about the bot, like memory usage.
* Fortune.pm - Wrapper for the `fortune` command.
