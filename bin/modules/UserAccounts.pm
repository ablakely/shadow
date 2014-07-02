package UserAccounts;

use BerkeleyDB;
my $bot = Shadow::Core;

tie my %db, "BerkeleyDB::Hash",
	-Filename => "../etc/users.dbm",
	-Flags    => DB_CREATE
	or warn "Cannot open database file: $! $BerkeleyDB::Error\n";

# Add handlers for our modules command set.
$bot->add_handler("privcmd register", usr_register);
$bot->add_handler("privcmd identify", usr_indetify);
$bot->add_handler("privcmd help", usr_help);

sub usr_register {
	my ($nick, $host, $text) = @_;
	my ($password, $email)   = split(" ", $text);

	if (exists $db{$email}) {
		$bot->notice($nick, "Error: That email is registered to an existing account.");
		return;
	} else {
		$db{$email} = { password => $password, regtime => localtime, flags => ''};
		push(@Shadow::Core::onlineusers, $nick);

		$bot->notice($nick, "You are now registered with $Shadow::Core::nick\.");
		$bot->notice($nick, "To see a list of commands avaliable, use \x02/msg $Shadow::Core::nick help\x02");
	}
}

sub usr_indetify {
	return;
}

sub usr_help {
	return;
}

1;