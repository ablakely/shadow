package Admin;

use Data::Dumper;

my $admin = "Dark_Aaron";
my $bot   = Shadow::Core;

$bot->add_handler('chancmd eval', irceval);
$bot->add_handler('chancmd dump', ircdump);

sub irceval {
	my ($nick, $host, $chan, $text) = @_;

	if ($nick eq $admin) {
		eval $text;
		$bot->notice($nick, $@) if $@;
	} else {
		$bot->notice($nick, "Unauthorized.")
	}
}

sub ircdump {
	my ($nick, $host, $chan, $text) = @_;

	if ($nick eq $admin) {
		my @output;
		eval "\@output = Dumper($text);";

		foreach my $line (@output) {
			$bot->notice($nick, $line);
		}
	} else {
		$bot->notice($nick, "Unauthorized.");
	}
}