package ChanServ;

use lib './Oper.pm';

my $bot = Shadow::Core;
my $jchan = "";

sub loader {
  $bot->add_handler('chancmd kill', 'ChanServ_kill');
  $bot->add_handler('event join', 'ChanServ_join');
  $bot->add_handler('event namesend', 'ChanServ_joinme');
}

sub ChanServ_join {
  my ($nick, $host, $chan) = @_;
  if ($bot->isbotadmin($nick, $host)) {
    $bot->raw("SAMODE $chan +o :$nick");
  }
}

sub ChanServ_joinme {
  my ($chan) = @_;

  $bot->listusers_async($chan, sub {
    my ($chan, @userlist) = @_;
    $bot->raw("SAMODE $chan +o :".$Shadow::Core::nick);

    foreach my $u (@userlist) {
      my $uhost = $bot->gethost($chan, $u);
      if ($bot->isbotadmin($u, $host)) {
        $bot->raw("SAMODE $chan +o :$u");
      }
    }
  });
}


sub ChanServ_kill {
  my ($nick, $host, $chan, $text) = @_;

  Oper::oper_kill($nick, $host, $text);
}

sub unloader {
  $bot->del_handler('chancmd kill', 'ChanServ_kill');
}

1;
