package Fortune;

# Fortune.pm - Wrapper package for the Unix fortune cookie program.
# Written by Aaron Blakely <aaron@ephasic.org>

my $bot  = Shadow::Core;
my $help = Shadow::Help;

sub whereisFortune {
	my @paths = ('/usr/games/fortune', '/usr/bin/fortune', '/usr/local/Cellar/fortune/9708/bin/fortune');

	foreach my $t (@paths) {
		if (-e $t) { return $t; }
	}

	return undef;

}

sub loader {
	if (!whereisFortune()) {
		$bot->log("[Fortune] Couldn't find the fortune executable.  Refusing to load.", "Modules");

		return -1;
	}

	$bot->register("Fortune", "v1.0", "Aaron Blakely");
	$bot->add_handler('chancmd fortune', 'doFortune');
	$help->add_help("fortune", "Game", "", "Fortune cookie! [F]", 0, sub {
		my ($nick, $host, $text) = @_;

		$bot->say($nick, "Help for \x02FORTUNE\x02:");
		$bot->say($nick, " ");
		$bot->say($nick, "\x02fortune\x02 print a random, hopefully interesting, adage");
		$bot->say($nick, "\x02SYNTAX\x02: .fortune");
	});
}


sub doFortune {
	my ($nick, $host, $chan, $text) = @_;
	
	my $bin = whereisFortune();
	my @fortune = `$bin -s`;

	$bot->say($chan, "Here's your fortune $nick:");
	foreach my $line (@fortune) {
		chomp $line;

		if (defined &Lolcat::lolcat) {
			Lolcat::lolcat($nick, $host, $chan, $line);
		} else {
			$bot->say($chan, $line);
		}
	}

	return @fortune;
}

sub unloader {
	$bot->unregister("Fortune");
	$bot->del_handler('chancmd fortune', 'doFortune');
	$help->del_help('fortune', 'Misc.');
}

1;
