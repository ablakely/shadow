package Debug;

# TODO: Make this a load in module that turns on CORE debugging
#

my $bot  = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  $bot->register("Debug", "v0.5", "Aaron Blakely");

  $bot->add_handler('raw in', 'debug_rawInEvent');
  $bot->add_handler('raw out', 'debug_rawOutEvent');
}

sub debug_rawInEvent {
  my ($raw) = @_;
  $bot->log("[DEBUG/RAW]: --> $raw", "Debug");
}

sub debug_rawOutEvent {
  my ($raw) = @_;

  $bot->log("[DEBUG/RAW]: <-- $raw", "Debug");
}

sub unloader {
  $bot->unregister("Debug");
  
  $bot->del_handler('raw in', 'debug_rawInEvent');
  $bot->del_handler('raw out', 'debug_rawOutEvent');
}

1;
