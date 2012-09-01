package Uptime;

my $bot = Shadow::Core;

$bot->add_handler('chancmd uptime', 'uptime_cmd');
sub uptime_cmd {
	my ($nick, $host, $chan, $text) = @_;

	my $uptime = `uptime`;
	chomp $uptime;

	$bot->say($chan, "Uptime: ".$uptime);
}

1;
