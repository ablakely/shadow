package ChanServ;

use lib './Oper.pm';

my $bot = Shadow::Core;

sub loader {
  $bot->add_handler('chancmd kill', 'ChanServ_kill');
}

sub ChanServ_kill {
  my ($nick, $host, $chan, $text) = @_;

  Oper::oper_kill($nick, $host, $text);
}

sub unloader {
  $bot->del_handler('chancmd kill', 'ChanServ_kill');
}

1;
