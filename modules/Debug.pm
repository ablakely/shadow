package Debug;

# TODO: Make this a load in module that turns on CORE debugging
#

use Shadow::Core;
use Shadow::Help;

my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
  $bot->register("Debug", "v0.5", "Aaron Blakely", "Debugging module");

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
