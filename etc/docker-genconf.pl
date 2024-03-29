#!/usr/bin/perl -w

use strict;
use warnings;

open(my $FH, ">", "./shadow.conf") or die "Cannot open shadow.conf: $!";

print $FH <<END;
# Shadow Configuration File
# Written by Aaron Blakely


\@Shadow

[IRC]
bot.host       = [$ENV{IRC_HOST}:$ENV{IRC_PORT}]
bot.nick       = "$ENV{IRC_NICK}"
bot.name       = "$ENV{IRC_NAME}"
bot.channels   = [$ENV{IRC_CHANS}]


# bot.cmdchan - Bot logging/control channel
bot.cmdchan = "$ENV{IRC_CMDCHAN}"

# bot.cmdchanlogtype - Defines which types of logs will be sent to log channel
# Types:
#   All      - All log messages (do not use with other types)
#   Error    - Error messages
#   System   - IRC/Core module related log messages
#   Modules  - Module activity such as loading, reloading, and unloading log messages
#   WebAdmin - HTTP/WebAdmin activity log messages
#
# Modules may add their own log types.

bot.cmdchanlogtype = [System,Error]

# Oper mode (used with modules like Oper, ChanServ)
# bot.oper = [oper name,oper pass]

# bot.cmdprefix - Defines which character is used to active channel commands
bot.cmdprefix = "."

[Bot]
system.daemonize    = no
system.modules      = [ChanOP,AutoID,WebAdmin]

[Admin]
# Comma separated list of hostnames (wildcards are accepted)
bot.admins = [$ENV{IRC_ADMINHOSTS}]

\@Modules
# Modules Section - Define settings for configuring modules.

[WebAdmin]

# httpd.addr - Defines which IP the WebAdmin HTTP server will listen on. 
httpd.addr = "0.0.0.0"

# httpd.port - Defines which port the WebAdmin HTTP server will listen on.
httpd.port = "$ENV{HTTP_PORT}"

# httpd.publicURL - Defines the URL that the webadmin is located at.
httpd.publicURL = "$ENV{HTTP_PUBURL}"

# sys.checkupdate - Automatically check for updates with git fetch
sys.checkupdate = yes
END