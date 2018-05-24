package Commands;

# Commands - Adds the .commands chancmd which lists all the active
#            chancmd handler commands.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# 5/23/18 - v1.0

my $bot = Shadow::Core;

sub loader {
  $bot->add_handler('chancmd commands', 'commands_dolist');
}

sub commands_dolist {
  my ($nick, $host, $chan, $text) = @_;

  my $cmdstr = "\x02Commands:\x02 ";
  foreach my $cmd (keys %Shadow::Core::handlers{'chancmd'}) {
    $cmdstr .= $Shadow::Core::options{irc}{cmdprefix}."$cmd ";
  }

  $bot->say($chan, $cmdstr);
}

sub unloader {
  $bot->del_handler('chancmd commands', 'commands_dolist');
}

1;
