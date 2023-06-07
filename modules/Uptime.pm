package Uptime;

# Shadow Module: Uptime
# This is a very basic module which adds a channel command "uptime",
# which prints the system's uptime in the channel.
#
# Written by Aaron Blakely <aaron@ephasic.org>



use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
	$bot->register("Uptime", "v1.0", "Aaron Blakely", "System uptime command");

	$bot->add_handler('chancmd uptime', 'uptime_cmd');
	$help->add_help("uptime", 'Channel', "", "Prints system's uptime to channel. [F]", 0, sub {
		my ($nick, $host, $text) = @_;

		$bot->say($nick, "Help for \x02UPTIME\x02:");
		$bot->say($nick, " ");
		$bot->say($nick, "Prints the system uptime and load average into the channel.");
		$bot->say($nick, "\x02SYNTAX\x02: .uptime");
	});
}

sub uptime_cmd {
	my ($nick, $host, $chan, $text) = @_;
	my $uptime;

	if ($^O =~ /msys/ || $^O =~ /MSWin32/) {
		$uptime = `sh neofetch uptime`;
	} else {
		$uptime = "uptime: ".`uptime`;
	}

	chomp $uptime;

	$bot->say($chan, $uptime);
}

sub unloader {
	$bot->unregister("Uptime");

	$bot->del_handler('chancmd uptime', 'uptime_cmd');
	$help->del_help("uptime", 'Channel');
}

1;
