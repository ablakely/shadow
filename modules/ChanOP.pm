package ChanOP;

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  $bot->add_handler('chancmd op',    'chanop_op');
  $bot->add_handler('privcmd op',    'chanop_op');
  $bot->add_handler('chancmd voice', 'chanop_voice');
  $bot->add_handler('privcmd voice', 'chanop_voice');
  $bot->add_handler('privcmd kick',  'chanop_kick');
  $bot->add_handler('chancmd kick',  'chanop_kick');
  $bot->add_handler('chancmd ban',   'chanop_ban');
  $bot->add_handler('privcmd ban',   'chanop_ban');

  $help->add_help('op', 'Channel', '<user> <channel>', 'Give or removes operator mode to a user. [F]', 0);
  $help->add_help('voice', 'Channel', '<user> <channel>', 'Gives or removes voice from a user. [F]', 0);
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

    if ($bot->isop($n, $c)) {
    	$bot->deop($c, $n);
    } else {
        $bot->op($c, $n);
    }
  }
}

sub chanop_voice {
  my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

  if ($bot->isbotadmin($nick, $host) || $bot->isop($nick, $chan)) {
    my ($n, $c) = split(/ /, $text);
    $c = $chan if !$c;

    if ($bot->isvoice($n, $c)) {
	$bot->devoice($c, $n);
    } else {
	$bot->voice($c, $n);
    }
  }
} 

sub unloader {
  $bot->del_handler('chancmd op',    'chanop_op');
  $bot->del_handler('privcmd op',    'chanop_op');
  $bot->del_handler('chancmd voice', 'chanop_voice');
  $bot->del_handler('privcmd voice', 'chanop_voice');
  $bot->del_handler('privcmd kick',  'chanop_kick');
  $bot->del_handler('chancmd kick',  'chanop_kick');
  $bot->del_handler('chancmd ban',   'chanop_ban');
  $bot->del_handler('privcmd ban',   'chanop_ban');


  $help->del_help('op', 'Channel');
  $help->del_help('voice', 'Channel');
  $help->del_help('kick', 'Channel');
  $help->del_help('ban', 'Channel');
}
1;
