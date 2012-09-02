#!/usr/bin/perl -w

# shadow: Perl IRC Bot
#
# Written by Aaron Blakely

use lib '../lib';
use strict;
use warnings;
use Shadow::Core;
use Shadow::Config;

$| = 1;

my $configfile		= $ARGV[0] || '../etc/shadow.conf';
my $configparser	= Shadow::Config->new($configfile);
my $config		= $configparser->parse();

#############################################################

my $serverlist 	= $config->{Shadow}->{IRC}->{bot}->{host};
my $nick	= $config->{Shadow}->{IRC}->{bot}->{nick};
my $name	= $config->{Shadow}->{IRC}->{bot}->{name};

my $bot = Shadow::Core->new($serverlist, $nick, $name, 0);

if ($config->{Shadow}->{Bot}->{system}->{daemonize} eq "yes") {
	exit if (fork());
	exit if (fork());
	sleep 1 until getppid() == 1;

	print $nick." [$$]: Successfully daemonized.\n";
}

#############################################################
#
# Right now, we'll just do this.
# Eventually, I will add a /correct/ channel joining function
#
$bot->add_handler('event connected', 'join_channels');
sub join_channels {
	my @chans = split(/\,/, $config->{Shadow}->{IRC}->{bot}->{channels});
	foreach my $channel (@chans) {
		$bot->join($channel);
	}
}


#############################################################

# Start the wheel...
$bot->connect();

