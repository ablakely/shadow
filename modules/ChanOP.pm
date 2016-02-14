package ChanOP;

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  $bot->add_handler('chancmd op',    'chanop_op');
  $bot->add_handler('privcmd op',    'chanop_op');
  $bot->add_handler('chancmd deop',  'chanop_deop');
  $bot->add_handler('privcmd deop',  'chanop_deop');
  $bot->add_handler('privcmd kick',  'chanop_kick');
  $bot->add_handler('chancmd kick',  'chanop_kick');
  $bot->add_handler('chancmd ban',   'chanop_ban');
  $bot->add_handler('privcmd ban',   'chanop_ban');

  $help->add_help('op', 'Channel', '<user> <channel>', 'Give operator mode to a user. [F]', 0);
  $help->add_help('deop', 'Channel', '<user> <channel>', 'Removes operator mode from a user. [F]', 0);
  $help->add_help('kick', 'Channel', '<user> <channel> <reason>', 'Kicks a user from a channel. [F]', 0);
  $help->add_help('ban', 'Channel', '<user> <channel> <reason>', 'Bans a user from a channel. [F]', 0);
}

sub chanop_kick {
  my ($nick, $host, $chan, $text) = @_;
  my ($user, $channel, @reason);

  if (!$text) {
    $text = $chan;
    ($user, $channel, @reason) = split(/ /, $text);
  } else {
    ($user, @reason) = split(/ /, $text);
    $channel = $chan;
  }

  my $r = join(" ", @reason) || $nick;

  if ($bot->isbotadmin($nick, $host) || $bot->isop($nick, $channel)) {
    $bot->kick($channel, $user, $r);
  }
}

sub chanop_ban {
  my ($nick, $host, $chan, $text) = @_;
  my ($user, $channel, @reason);

  if (!$text) {
    $text = $chan;
    ($user, $channel, @reason) = split(/ /, $text);
  } else {
    ($user, @reason) = split(/ /, $text);
    $channel = $chan;
  }

  my $r = join(" ", @reason) || $nick;

  if ($bot->isbotadmin($nick, $host) || $bot->isop($nick, $channel)) {
    my $bhost = $Shadow::Core::sc{lc($channel)}{users}{$user}{host};
    $bhost =~ s/^(.*)\@//;
    $bhost = "*!*@".$bhost;

    $bot->mode($channel, "+b", $bhost);
    $bot->kick($channel, $user, $r);
  }
}

sub chanop_op {
  my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

  if ($bot->isbotadmin($nick, $host) || $bot->isop($nick, $chan)) {
    my ($n, $c) = split(/ /, $text);
    $c = $chan if !$c;

    $bot->op($c, $n);
  }
}

sub chanop_deop {
  my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

  if ($bot->isbotadmin($nick, $host) || $bot->isop($nick, $chan)) {
    my ($n, $c) = split(/ /, $text);
    $c = $chan if !$c;

    $bot->deop($c, $n);
  }
}

1;
