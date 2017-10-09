package Lamp;

use LWP::Simple;

my $arduinoip = "192.168.1.202";
my $bot = Shadow::Core;

sub loader {
	$bot->add_handler('chancmd lamp', 'lamp_control');
}

sub lamp_control {
	my ($nick, $host, $chan, $text) = @_;

	return if (!$bot->isbotadmin($nick, $host));

	if ($text eq "on") {
		get("http://$arduinoip/?on");
		$bot->say($chan, "turning the lamp on");
	} elsif ($text eq "off") {
		get("http://$arduinoip/?off");
		$bot->say($chan, "turning the lamp off");
	}
}

sub unloader {
	$bot->del_handler('chancmd lamp', 'lamp_control');
}

1;
