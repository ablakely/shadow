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
		$db{$email} = { password => $password, regtime => localtime, flags => '', host => $host };
		push(@Shadow::Core::onlineusers, "$nick:$host:$email");

		$bot->notice($nick, "You are now registered with the email $email.\.");
		$bot->notice($nick, "To see a list of commands avaliable, use \x02/msg $Shadow::Core::nick help\x02");
	}
}

sub usr_indetify {
	return;
}

sub usr_help {
	my ($nick, $host, $topic) = @_;
		$bot->notice($nick, "\x02--- Shadow Help ---\x02");
		$bot->notice($nick, "- \x02Shadow ($Shadow::Core::nick)\x02 provides users with advanced features to enrich the overall IRC experience,");
		$bot->notice($nick, "- it provides various such as channel management, flood control, user accounts, social network integration and various");
		$bot->notice($nick, "- other features for users to enjoy.");
		$bot->notice($nick, "-");
		$bot->notice($nick, "- \x02Available Commands:\x02");
		$bot->notice($nick, "-   \x02register\x02     - Creates a user account.");
		$bot->notice($nick, "-   \x02identify\x02     - Logs you into your account.");
		$bot->notice($nick, "-   \x02reqchan\x02      - Submit a channel request.");
		$bot->notice($nick, "-   \x02chanmgmt\x02     - Channel management settings.");
		$bot->notice($nick, "-   \x02social\x02       - Social network integration settings.");
		$bot->notice($nick, "-   \x02stats\x02        - Bot statistics.");
		$bot->notice($nick, "-");
		$bot->notice($nick, "- For advanced help on a command please use: \x02/msg $Shadow::Core::nick help <command>");
}

sub check_flag {
	my ($email, $flag) = @_;

	my @flags = split("", $db{$email}{flags});
	foreach my $f ($flags) {
		if ($f eq $flag) {
			return 1;
		}
	}

	return undef;
}

1;