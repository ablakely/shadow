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
  $self->{bot}->add_handler('privcmd modlist', 'ircadmin_modlist');
  $self->{bot}->add_handler('privcmd loadmod', 'ircadmin_loadmod');
  $self->{bot}->add_handler('privcmd rmmod', 'ircadmin_rmmod');

  $self->{bot}->{help}->add_help('modlist', 'Admin', '', 'See all modules currently loaded.', 1);
  $self->{bot}->{help}->add_help('loadmod', 'Admin', '<module>', 'Load a module.', 1);
  $self->{bot}->{help}->add_help('rmmod', 'Admin', '<module>', 'Unload a module.', 1);
  $self->{bot}->{help}->add_help('eval', 'Admin', '<text>', 'Evaluates perl code. [F]', 1);
  $self->{bot}->{help}->add_help('dump', 'Admin', '<var>', 'Dumps a structure and notices it to you. [F]', 1);
  $self->{bot}->{help}->add_help('join', 'Admin', '<channel>', 'Force bot to join a channel.', 1);
  $self->{bot}->{help}->add_help('part', 'Admin', '<channel>', 'Force bot to part a channel.', 1);

  return bless($self, $class);
}


sub ircadmin_loadmod {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Loading module: $text");
    $bot->load_module($text);
  }
}

sub ircadmin_rmmod {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Unloading module: $text");
    $bot->unload_module($text);
  }
}

sub ircadmin_modlist {
  my ($nick, $host, $text) = @_;

  return if !$bot->isbotadmin($nick, $host);

  $bot->notice($nick, "\x02*** LOADED MODULES ***\x02");

  my %modlist = $bot->module_stats();
  my $modstr  = "";
  foreach my $mod (keys %modlist) {
    next if ($mod eq "loadedmodcount");

    $modstr .= "$mod, ";
  }

  $bot->notice($nick, $modstr);
  $bot->notice($nick, "There are ".$modlist{loadedmodcount}." modules loaded.");
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
