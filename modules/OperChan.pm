package OperChan;

use Shadow::Core;

my $bot = Shadow::Core->new();

my @channels = ("#network", "#staff");

sub loader {
  $bot->add_handler('event join', "operchan_join"); 
}

sub operchan_join {
  my ($nick, $hostname, $chan) = @_;

  $bot->raw("USERHOST $nick");

  foreach my $ochan (@channels) {
    if ($ochan eq $chan && !$Shadow::Core::sc{lc($chan)}{users}{$nick}{oper}) {
      $bot->kick($chan, $nick, "IRC Operators only");
    }
  } 
}

sub unloader {
  $bot->del_handler('event join', "operchan_join");
}

1;
