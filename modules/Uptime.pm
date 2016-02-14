package Uptime;

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
