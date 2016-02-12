package Admin;

use Data::Dumper;

my $admin = "Dark_Aaron";
my $bot   = Shadow::Core;

$bot->add_handler('chancmd eval', ircadmin_eval);
$bot->add_handler('chancmd dump', ircadmin_dump);

sub ircadmin_eval {
	my ($nick, $host, $chan, $text) = @_;

	if ($nick eq $admin) {
		eval $text;
		$bot->notice($nick, $@) if $@;
	} else {
		$bot->notice($nick, "Unauthorized.")
	}
}

sub ircadmin_dump {
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
