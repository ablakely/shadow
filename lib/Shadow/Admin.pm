package Shadow::Admin;

use strict;
use warnings;
use Data::Dumper;

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
  $self->{bot}->add_handler('chancmd cat',   'ircadmin_cat');
  $self->{bot}->add_handler('privcmd cat',   'ircadmin_cat');
  $self->{bot}->add_handler('privcmd eval',  'ircadmin_eval');
  $self->{bot}->add_handler('privcmd join',  'ircadmin_join');
  $self->{bot}->add_handler('privcmd part',  'ircadmin_part');
  $self->{bot}->add_handler('privcmd modlist', 'ircadmin_modlist');
  $self->{bot}->add_handler('privcmd loadmod', 'ircadmin_loadmod');
  $self->{bot}->add_handler('privcmd rmmod', 'ircadmin_rmmod');

  $self->{bot}->{help}->add_help('cat', 'Admin', '<file path>', 'Dump a file [F]', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02CAT\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02cat\x02 is a command that reads a file and returns its contents, like the shell command.");
    $bot->say($nick, "\x02SYNTAX\x02: .cat <file> or /msg $Shadow::Core::nick cat <file>");
  });

  $self->{bot}->{help}->add_help('modlist', 'Admin', '', 'See all modules currently loaded.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02MODLIST\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02modlist\x02 is a command that lists all the modules currently loaded into Shadow.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick modlist");
  });

  $self->{bot}->{help}->add_help('loadmod', 'Admin', '<module>', 'Load a module.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02LOADMOD\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02loadmod\x02 is a command for dynamically loading shadow modules.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick loadmod <module>");
  });

  $self->{bot}->{help}->add_help('rmmod', 'Admin', '<module>', 'Unload a module.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02RMMOD\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02rmmod\x02 is a command for dynamically unloading shadow modules.");
  });

  $self->{bot}->{help}->add_help('eval', 'Admin', '<text>', 'Evaluates perl code. [F]', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02EVAL\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02eval\x02 is a command that executes perl code.  Do not play with this unless you know what you're doing.");
    $bot->say($nick, "Examples:");
    $bot->say($nick, '  .eval for (my $i = 0; $i < 10; $i++) { $bot->say($chan, "hi Scally"); }');
    $bot->say($nick, '  .eval $Shadow::Core::options{irc}->{cmdprfix} = "!";');
    $bot->say($nick, '  .eval system "kill $$";');
    $bot->say($nick, " ");
    $bot->say($nick, "\x02SYNTAX\x02: .eval <perl code> or /msg $Shadow::Core::nick eval <perl code>");
  });

  $self->{bot}->{help}->add_help('dump', 'Admin', '<var>', 'Dumps a structure and notices it to you. [F]', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02DUMP\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02dump\x02 uses the Perl Data::Dumper module to dump a data structure and then it notices it to you.");
    $bot->say($nick, "This is helpful when debugging your custom modules.");
    $bot->say($nick, "\x02SYNTAX\x02: .dump <var|array|hash>");
  });

  $self->{bot}->{help}->add_help('join', 'Admin', '<channel>', 'Force bot to join a channel.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02JOIN\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "Forces the bot to join a channel.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick join #chan");
  });

  $self->{bot}->{help}->add_help('part', 'Admin', '<channel>', 'Force bot to part a channel.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02PART\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "Forces the bot to part a channel.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick part #chan");
  });

  return bless($self, $class);
}


sub ircadmin_loadmod {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Loading module: $text");
    $bot->log("Loading module: $text [Issued by $nick]");
    $bot->load_module($text);
  }
}

sub ircadmin_rmmod {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Unloading module: $text");
    $bot->log("Unloading module: $text [Issued by $nick]");
    $bot->unload_module($text);
  }
}

sub ircadmin_modlist {
  my ($nick, $host, $text) = @_;

  my $ALL_MODS = 0;

  if ($text =~ /all/) {
    $ALL_MODS = 1;
  }

  return if !$bot->isbotadmin($nick, $host);

  $bot->notice($nick, "\x02*** LOADED MODULES ***\x02");

  my %modlist = $bot->module_stats();
  my $modstr  = "";
  foreach my $mod (keys %modlist) {
    next if ($mod eq "loadedmodcount");

    if ($ALL_MODS) {
      $modstr .= "$mod, ";
    } else {
      if ($mod =~ /Shadow\:\:Mods\:\:/) {
        $modstr .= "$mod, ";
      }
    }
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

sub ircadmin_cat {
  my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

  if ($bot->isbotadmin($nick, $host)) {
    open(my $fh, "<", $text) or $bot->notice($nick, $!);
    my @con = <$fh>;
    close $fh;

    my $lc = 0;
    foreach my $line (@con) {
      if ($chan !~ /^\#/) {
        $bot->notice($nick, "$text:$lc: $line");
      } else {
        $bot->say($chan, "$text:$lc: $line");
      }

      $lc++;
    }
  } else {
    $bot->notice($nick, "Unauthorized.")
  }
}

sub ircadmin_eval {
	my ($nick, $host, $chan, $text) = @_;
  if (!$text) {
    $text = $chan;
  }

	if ($bot->isbotadmin($nick, $host)) {
		eval $text;
    if ($@) {
      $bot->notice($nick, "Eval error: $@");
    }
	} else {
		$bot->notice($nick, "Unauthorized.")
	}
}

sub ircadmin_dump {
  my ($nick, $host, $chan, $text) = @_;
  $text = $chan if !$text;

  if ($bot->isbotadmin($nick, $host)) {
    my @output;
    eval "\@output = Dumper(".$text.")";
    $bot->notice($nick, "dump error: $@") if $@;

    foreach my $line(@output) {
      if ($chan !~ /^\#/) {
        $bot->notice($nick, $line);
      } else {
        $bot->say($chan, $text);
      }
    }
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

1;
