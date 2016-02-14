package Shadow::Admin;

use strict;
use warnings;

our $bot;
our %options;

sub new {
  my ($class, $shadow) = @_;
  $bot = $shadow;
  my $self = {
    bot => $bot
  };

  $self->{bot}->add_handler('chancmd eval',  'ircadmin_eval');
  $self->{bot}->add_handler('chancmd dump',  'ircadmin_dump');
  $self->{bot}->add_handler('privcmd eval',  'ircadmin_eval');
  $self->{bot}->add_handler('privcmd join',  'ircadmin_join');
  $self->{bot}->add_handler('privcmd part',  'ircadmin_part');
  $self->{bot}->add_handler('chancmd op',    'ircadmin_op');
  $self->{bot}->add_handler('privcmd op',    'ircadmin_op');
  $self->{bot}->add_handler('chancmd deop',  'ircadmin_deop');
  $self->{bot}->add_handler('privcmd deop',  'ircadmin_deop');
  $self->{bot}->add_handler('privcmd kick',  'ircadmin_kick');
  $self->{bot}->add_handler('chancmd kick',  'ircadmin_kick');
  $self->{bot}->add_handler('chancmd ban',   'ircadmin_ban');
  $self->{bot}->add_handler('privcmd ban',   'ircadmin_ban');

  $self->{bot}->{help}->add_help('eval', '<text>', 'Evaluates perl code. [F]', 1);
  $self->{bot}->{help}->add_help('dump', '<var>', 'Dumps a structure and notices it to you.', 1);
  $self->{bot}->{help}->add_help('join', '<channel>', 'Force bot to join a channel.', 1);
  $self->{bot}->{help}->add_help('part', '<channel>', 'Force bot to part a channel.', 1);
  $self->{bot}->{help}->add_help('op', '<user> <channel>', 'Give operator mode to a user. [F]', 0);
  $self->{bot}->{help}->add_help('deop', '<user> <channel>', 'Removes operator mode from a user. [F]', 0);
  $self->{bot}->{help}->add_help('kick', '<user> <channel> <reason>', 'Kicks a user from a channel. [F]', 0);
  $self->{bot}->{help}->add_help('ban', '<user> <channel> <reason>', 'Bans a user from a channel. [F]', 0);

  return bless($self, $class);
}

sub check_admin {
  my ($self, $nick, $host, $channel, $text) = @_;

  my $admins = $bot->{cfg}->{Shadow}->{Admin}->{bot}->{admins};
  my @tmp    = split(',', $admins);

  foreach my $t (@tmp) {
    my ($u, $h) = split(/\!/, $t);

    if ($u eq $nick || $u eq "*") {
      my ($ar, $ahm) = split(/\@/, $host);
      my ($r, $hm) = split(/\@/, $h);

      if ($r eq "*" && $hm ne "*") {
        return 1 if $hm eq $ahm;
      }
      elsif ($r ne "*" && $hm eq "*") {
        return 1 if $r eq $ar;
      }
      elsif ($r eq "*" && $hm eq "*") {
        return 1 if $u eq $nick;
      } else {
        return 1 if $r eq $ar && $hm eq $ahm;
      }
    }
  }

  return 0;
}

sub ircadmin_kick {
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

sub ircadmin_ban {
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

sub ircadmin_join {
  my ($nick, $host, $text) = @_;
  if ($bot->isbotadmin($nick, $host)) {
    $bot->join($text);
  }
}

sub ircadmin_part {
  my ($nick, $host, $text) = @_;
  if ($bot->isbotadmin($nick, $host)) {
    my ($chan, @reason) = split(/ /, $text);
    my $r = join(" ", @reason);
    $bot->part($chan, $r);
  }
}

sub ircadmin_op {
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

sub ircadmin_deop {
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

sub ircadmin_eval {
	my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

	if ($bot->isbotadmin($nick, $host)) {
		eval $text;
		$bot->notice($nick, $@) if $@;
	} else {
		$bot->notice($nick, "Unauthorized.")
	}
}


sub ircadmin_dump {
	my ($nick, $host, $chan, $text) = @_;

	if ($bot->isbotadmin($nick, $host)) {
		my @output;
		eval "\@output = Dumper($text);";

		foreach my $line (@output) {
			$bot->notice($nick, $line);
		}
	} else {
		$bot->notice($nick, "Unauthorized.");
	}
}

1;
