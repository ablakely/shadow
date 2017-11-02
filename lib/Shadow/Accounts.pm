package Shadow::Accounts;

# Shadow::Accounts - User Accounts for Shadow
# This module implements individual user accounts for maintaining privledges
# as well as storing user prefrences.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use strict;
use warnings;
use JSON;
use Digest::SHA qw(sha256_base64);
use Data::Dumper;

our $bot;
my $dbfile = "./etc/users.db";

# constructor
sub new {
	my ($class, $shadow) = @_;
	my $self             = {};
	$bot                 = $shadow;

	create_irc_interface($bot);
	if (!-e $dbfile) {
		$bot->log("Accounts: No DB file found, creating one...");
		open(my $db, ">", $dbfile) or $bot->err("Accounts: [Error] couldn't open account database file");
		print $db "[]\n";
		close($db);
	}

	return bless($self, $class);
}

sub accounts_readdb {
	my ($jsonstr, @dbread);

	open(my $db, "<", $dbfile) or $bot->err("Accounts: [Error] couldn't open account database file");
	while (my $line = <$db>) {
		chomp $line;
		$jsonstr .= $line;
	}
	close($db);

	return from_json($jsonstr, { utf8 => 1 });	
}

sub accounts_writedb {
	my ($data)  = @_;
	my $jsonstr = to_json($data, { utf8 => 1, pretty => 1});

	open(my $db, ">", $dbfile) or $bot->err("Accounts: [Error] couldn't open account database file");
	print $db $jsonstr;
	close($db);
}

sub accounts_readUserField {
	my ($email, $field) = @_;
	my $db = accounts_readdb();


	for (my $c = 0; $c < scalar(@{$db}); $c++) {
		if (@{$db}[$c]->{$field}) {
			return \@{$db}[$c]->{$field};
		}
	}
}

sub accounts_writeUserField {
	my ($email, $field, $value) = @_;
	my $db = accounts_readdb();

	for (my $c = 0; $c < scalar(@{$db}); $c++) {
		if (@{$db}[$c]->{$field}) {
			@{$db}[$c]->{$field} = $value;

			accounts_writedb($db);
			return 1;
		}
	}

	return 0;
}

sub accounts_writeUserFieldArray {
	my ($email, $field, $value) = @_;
	my $db = accounts_readdb();

	for (my $c = 0; $c < scalar(@{$db}); $c++) {
		if (@{$db}[$c]->{email} eq $email) {
			@{$db}[$c]->{$field} = $value if $value;

			accounts_writedb($db);
			return 1;
		}
	}

	return 0;
}


sub get_account {
	my ($self, $email) = @_;

	my $db = accounts_readdb();
	foreach my $user (@{$db}) {
		if (%{$user}{email} eq $email) {
			return $user;
		}
	}
}

sub create_irc_interface {
	my ($bot) = @_;

	$bot->add_handler('privcmd register', 'doRegister');
	$bot->add_handler('privcmd login', 'doLogin');
}

sub doLogin {
	my ($nick, $host, $text) = @_;
	my ($email, $password) = split(/ /, $text);
	if (!$email || !$password) {
		return $bot->say($nick, "Syntax: \x002login\x002 <email> <password>");
	}

	my (@sessions, %sesh, $user, $hashedpass, $ctime, $c);

	if ($user = get_account(0, $email)) {
		$hashedpass = sha256_base64($password);
		$ctime = localtime();

		if (%{$user}{password} eq $hashedpass) {
			@sessions = accounts_readUserField($email, "sessions");

			if (@sessions) {
			print Dumper(@sessions) if grep {!defined($_)} @sessions;
			print scalar(@sessions)."-".$#sessions."\n\n";
			print "------------\n";
		}

			%sesh = (
				nick    => $nick,
				host    => $host,
				created => $ctime
			);

			$c = scalar(@sessions);
			if ( grep {!defined($_)} @sessions) {
				$c = 0;
				$sessions[$c] = \%sesh;
			} else {
				push(@sessions, \%sesh);
			}

			accounts_writeUserFieldArray($email, "sessions", @sessions);

			print Dumper(@sessions);
			$bot->say($nick, "You are now logged in with the account: ".%{$user}{email});
		} else {
			$bot->say($nick, "Invalid username/password combination.");
		}
	}
}

sub doRegister {
	my ($nick, $host, $text) = @_;

	if (!$text) {
		return $bot->say($nick, "Syntax: \x002register\x002 <email> <password>");
	}

	my $db = accounts_readdb();
	my ($email, $password) = split(/ /, $text);
	my $hash = sha256_base64($password);
	my $ctime = localtime();

	# TODO: Implement email validation system
	my %newAccount = (
		email       => $email,
		password    => $hash,
		createdTime => $ctime,
		prefrences  => {},
		sessions => (),
	);

	push(@{$db}, \%newAccount);
	accounts_writedb($db);

	$bot->log("[Accounts] $nick created the account: $email");
	$bot->say($nick, "Account created: $email");
}

1;