# Shadow Perl IRC Bot

## What is shadow?
shadow is a modular IRC bot written in Perl by Aaron Blakely, it's goal is to be a stable IRC bot with cool features.

## Where can I get support for shadow?
  * Try irc.ephasic.org #shadow
  * `/msg bot help` 


# Installing
Installing Shadow is very simple thanks to our dependency installer, just run `installdepends.pl` and let the script prepare your environment.  See below for specific instructions related to your operating system.

## Docker
    sudo docker -d -p 1337:1337 -e IRC_NICK=MyBot --name shadow ab3800/shadow

See [shadow-docker](https://github.com/ablakely/shadow-docker) for more information about configuring the bot with environment variables.

## Linux
To install on debian/ubuntu systems you will need to following packages:
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

| Module           | Description                                                                      |
|------------------|----------------------------------------------------------------------------------|
| WebAdmin.pm      | Web Administration Panel                                                         |
| Aliases.pm       | Custom channel triggered responses                                               |
| Commands.pm      | Provides list of channel commands                                                | 
| RSS.pm           | RSS Feed Reader                                                                  |
| AutoID.pm        | Automatically authenticate with network services                                 |
| ChanOP.pm        | Basic channel management commands                                                |
| Uptime.pm        | Basic module which gives *nix uptime info (requires neofetch for Windows)        |
| Autojoin.pm      | Automatically join channels on connect                                           |
| URLIdentifier.pm | Automatically fetches the title of a URL                                         |
| BotStats.pm      | [Linux/Windows] Returns information about the bot, like memory usage             |
| Fortune.pm       | [*nix/Mac] Wrapper for the `fortune` command                                     |
| Weather.pm       | Fetches weather information for a given location                                 |
| Welcome.pm       | Greets users when they enter a channel                                           |
| MacSysInfo.pm    | System information using `system_profiler`                                       |
| Neofetch.pm      | System information using `neofetch`                                              |
| Lolcat.pm        | [lolcat](https://github.com/busyloop/lolcat) for IRC (kinda)                     |
| Ignore.pm        | Allows bot admins to make the bot ignore users                                   |
| MSLParser.pm     | (Alpha) mIRC Scripting Language parser                                           |

 
