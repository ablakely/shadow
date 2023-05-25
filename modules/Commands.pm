package Commands;

# Commands - Adds the .commands chancmd which lists all the active
#            chancmd handler commands.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# 5/23/18 - v1.0
# 6/17/22 - v1.1 - Now lists commands from the Aliases module.

use Shadow::Core;

my $bot = Shadow::Core->new();

sub loader {
  $bot->register("Commands", "v1.1", "Aaron Blakely", "List of commands available in the channel");
  $bot->add_handler('chancmd commands', 'commands_dolist');
}

sub commands_dolist {
  my ($nick, $host, $chan, $text) = @_;

  my $cmdstr = "\x02Bot Commands:\x02 ";
  foreach my $cmd (keys %{$Shadow::Core::handlers{'chancmd'}}) {
    $cmdstr .= $Shadow::Core::options{irc}{cmdprefix}."$cmd ";
  }

  if (exists &Aliases::_dbread) {
    my $adb = Aliases::_dbread();
    my $acmdstr = "\x02$chan Commands:\x02 ";

    foreach my $atrig (keys %{$adb->{lc($chan)}}) {
      $acmdstr .= "!$atrig ";
    }

    $bot->say($chan, $acmdstr);
  }

  $bot->say($chan, $cmdstr);
}

sub unloader {
  $bot->unregister("Commands");
  $bot->del_handler('chancmd commands', 'commands_dolist');
}

1;
