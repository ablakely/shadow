package Debug;

# TODO: Make this a load in module that turns on CORE debugging
#

my $bot  = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  $bot->add_handler('raw in', 'debug_rawEvent');
}

sub debug_rawEvent {
  my ($raw) = @_;
  print "[DEBUG/RAW]: $raw\n";
}

sub unloader {
  $bot->del_handler('raw in', 'debug_rawEvent');
}

1;
