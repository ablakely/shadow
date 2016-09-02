package Uptime;

# Shadow Module: Uptime
# This is a very basic module which adds a channel command "uptime",
# which prints the system's uptime in the channel.
#
# Written by Aaron Blakely <aaron@ephasic.org>

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
	$bot->add_handler('chancmd uptime', 'uptime_cmd');
	$help->add_help("uptime", 'Channel', "", "Prints system's uptime to channel. [F]", 0);
}

sub uptime_cmd {
	my ($nick, $host, $chan, $text) = @_;

	my $uptime = `uptime`;
	chomp $uptime;

	$bot->say($chan, "Uptime: ".$uptime);
}

sub unloader {
	$bot->del_handler('chancmd uptime', 'uptime_cmd');
	$help->del_help("uptime", 'Channel');
}

1;
