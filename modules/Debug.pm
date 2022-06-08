package Debug;

# TODO: Make this a load in module that turns on CORE debugging
#

my $bot  = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  $bot->add_handler('raw in', 'debug_rawEvent');
  $bot->add_handler('event mode', 'debug_modeEvent');
}

sub debug_rawEvent {
  my ($raw) = @_;
  print "[DEBUG/RAW]: $raw\n";
}

sub debug_modeEvent {
  my ($nick, $host, $chan, $act, @mode) = @_;

  print "MODE SET: $nick, $host, $chan, $act, [";
  foreach my $m (@mode) {
    print "$m,";
  }
  print "]\n";
}

sub unloader {
  $bot->del_handler('raw in', 'debug_rawEvent');
  $bot->del_handler('event mode', 'debug_modeEvent');
}

1;
