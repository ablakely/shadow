#!/usr/bin/perl -w

# shadow: Perl IRC Bot
#
# Written by Aaron Blakely

use strict;
use warnings;
use Shadow::Core;
use Shadow::Config;

$| = 1;

my $configfile		= $ARGV[0] || 'shadow.conf';
my $configparser	= Shadow::Config->new($configfile);
my $config		= $configparser->parse();

#############################################################

my $serverlist 	= $config->{Shadow}->{IRC}->{bot}->{host};
my $nick	= $config->{Shadow}->{IRC}->{bot}->{nick};
my $name	= $config->{Shadow}->{IRC}->{bot}->{name};

my $bot = Shadow::Core->new($serverlist, $nick, $name, 0);

exit if (fork());
exit if (fork());
sleep 1 until getppid() == 1;

print "gitbot[$$]: Successfully daemonized.\n";

#############################################################

$bot->add_handler('event connected', 'join_channels');

sub join_channels {
	$bot->join('#cruzrr');
}

$bot->add_handler('chanmecmd hello', 'say_hi');
sub say_hi {
	my ($nick, $host, $channel, $text) = @_;

	$bot->say($channel, "hi");
	
	return;
}

$bot->add_handler('chanmecmd chgprefix', 'change_prefix');
sub change_prefix {
	my ($nick, $host, $channel, $text) = @_;

	if ($nick eq "Dark_Aaron") {
		$Shadow::Core::options{irc}{cmdprefix} = $text;
		$bot->say($channel, "Command prefix is now: $text");
	} else {
		$bot->say($channel, "Access denied.");
	}
}

$bot->load_module("Uptime");
#$bot->load_module("Console");

#############################################################

$bot->connect();

