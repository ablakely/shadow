package Shadow::Admin;

use strict;
use warnings;
use Data::Dumper;

use Shadow::Core;

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
  $self->{bot}->add_handler('privcmd reload', 'ircadmin_reload');
  $self->{bot}->add_handler('privcmd rehash', 'ircadmin_rehash');
  $self->{bot}->add_handler('privcmd shutdown', 'ircadmin_shutdown');
  $self->{bot}->add_handler('privcmd restart', 'ircadmin_restart');

  $self->{bot}->{help}->add_help('restart', 'Admin', '', 'Restarts the bot.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02RESTART\x02:");
    push(@out, " ");
    push(@out, "\x02restart\x02 is used to restart the bot.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick restart");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('rehash', 'Admin', '', 'Rehashes the configuration file.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02REHASH\x02:");
    push(@out, " ");
    push(@out, "\x02rehash\x02 is used to reload the configuration file.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick rehash");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('shutdown', 'Admin', '', 'Shuts down the bot.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02SHUTDOWN\x02:");
    push(@out, " ");
    push(@out, "\x02shutdown\x02 is used to stop the bot.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick shutdown");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('cat', 'Admin', '<file path>', 'Dump a file [F]', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02CAT\x02:");
    push(@out, " ");
    push(@out, "\x02cat\x02 is a command that reads a file and returns its contents, like the shell command.");
    push(@out, "\x02SYNTAX\x02: .cat <file> or /msg $Shadow::Core::nick cat <file>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('modlist', 'Admin', '', 'See all modules currently loaded.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02MODLIST\x02:");
    push(@out, " ");
    push(@out, "\x02modlist\x02 is a command that lists all the modules currently loaded into Shadow.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick modlist");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('loadmod', 'Admin', '<module>', 'Load a module.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02LOADMOD\x02:");
    push(@out, " ");
    push(@out, "\x02loadmod\x02 is a command for dynamically loading shadow modules.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick loadmod <module>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('rmmod', 'Admin', '<module>', 'Unload a module.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02RMMOD\x02:");
    push(@out, " ");
    push(@out, "\x02rmmod\x02 is a command for dynamically unloading shadow modules.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick rmmod <module>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('reload', 'Admin', '<module>', 'Reloads a module.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02RELOAD\x02:");
    push(@out, " ");
    push(@out, "\x02reload\x02 is a command for dynamically reloading shadow modules.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick reload <module>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('eval', 'Admin', '<text>', 'Evaluates perl code. [F]', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02EVAL\x02:");
    push(@out, " ");
    push(@out, "\x02eval\x02 is a command that executes perl code.  Do not play with this unless you know what you're doing.");
    push(@out, "Examples:");
    push(@out, '  .eval for (my $i = 0; $i < 10; $i++) { $bot->say($chan, "hi Scally"); }');
    push(@out, '  .eval $Shadow::Core::options{irc}->{cmdprfix} = "!";');
    push(@out, '  .eval system "kill $$";');
    push(@out, " ");
    push(@out, "\x02SYNTAX\x02: .eval <perl code> or /msg $Shadow::Core::nick eval <perl code>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('dump', 'Admin', '<var>', 'Dumps a structure and notices it to you. [F]', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02DUMP\x02:");
    push(@out, " ");
    push(@out, "\x02dump\x02 uses the Perl Data::Dumper module to dump a data structure and then it notices it to you.");
    push(@out, "This is helpful when debugging your custom modules.");
    push(@out, "\x02SYNTAX\x02: .dump <var|array|hash>");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('join', 'Admin', '<channel>', 'Force bot to join a channel.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02JOIN\x02:");
    push(@out, " ");
    push(@out, "Forces the bot to join a channel.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick join #chan");

    $bot->fastsay($nick, @out);
  });

  $self->{bot}->{help}->add_help('part', 'Admin', '<channel>', 'Force bot to part a channel.', 1, sub {
    my ($nick, $host, $text) = @_;
    my @out;

    push(@out, "Help for \x02PART\x02:");
    push(@out, " ");
    push(@out, "Forces the bot to part a channel.");
    push(@out, "\x02SYNTAX\x02: /msg $Shadow::Core::nick part #chan");

    $bot->fastsay($nick, @out);
  });

  return bless($self, $class);
}


sub ircadmin_loadmod {
  my ($nick, $host, $text) = @_;

  if ($text eq "") {
    return $bot->notice($nick, "Command Usage: loadmod <module>")
  }

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Loading module: $text");
    $bot->log("Loading module: $text [Issued by $nick]");
    $bot->load_module($text);
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_rmmod {
  my ($nick, $host, $text) = @_;

  if ($text eq "") {
    return $bot->notice($nick, "Command Usage: rmmod <module>");
  }

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Unloading module: $text");
    $bot->log("Unloading module: $text [Issued by $nick]");
    $bot->unload_module($text);
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_reload {
  my ($nick, $host, $text) = @_;

  if ($text eq "") {
    return $bot->notice($nick, "Command Usage: reload <module>");
  }

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Reloading module: $text");
    $bot->log("Reloading module: $text [Issued by $nick]");
    $bot->reload_module($text);
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_modlist {
  my ($nick, $host, $text) = @_;
  return if !$bot->isbotadmin($nick, $host);

  my $fmt = Shadow::Formatter->new();

  $fmt->table_header("Module", "Version", "Author", "Description");

  my %modlist = $bot->module_stats();
  my %modreg  = %Shadow::Core::modreg;

  my @tmp;
  foreach my $mod (keys %modlist) {
    next if ($mod eq "loadedmodcount");

    if ($mod =~ /Shadow\:\:Mods\:\:(.*)/) {
      if (exists($modreg{$1})) {
        $fmt->table_row(
          $1,
          exists($modreg{$1}->{version}) ? $modreg{$1}->{version} : "N/A",
          exists($modreg{$1}->{author}) ? $modreg{$1}->{author} : "N/A",
          exists($modreg{$1}->{description}) ? $modreg{$1}->{description} : "N/A"
        );
      }
    }
  }

  $bot->fastsay($nick, $fmt->table());
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
    my @out;
    close $fh;

    my $lc = 0;
    foreach my $line (@con) {
      push(@out, "$text:$lc: $line");
      $lc++;
    }

    if ($chan =~ /^\#/) {
      $bot->fastsay($chan, @out);
    } else {
      $bot->fastnotice($chan, @out);
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

    if ($chan !~ /^\#/) {
      $bot->fastnotice($nick, @output);
    } else {
      $bot->fastsay($nick, @output);
    }

  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_rehash {
  my ($nick, $host, $chan, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->rehash();
    $bot->log("Rehashing configuration. [Issued by $nick]");
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_shutdown {
  my ($nick, $host, $chan, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->log("Shutting down... [Issued by $nick]");

    if (exists($ENV{STARTER_PID})) {
      system "kill -9 ".$ENV{STARTER_PID};
      exit;
    } else {
      exit;
    }
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub ircadmin_restart {
  my ($nick, $host, $chan, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->log("Restarting... [Issued by $nick]");

    if (exists($ENV{STARTER_PID})) {
      exit;
    } else {
      system "$0 && sleep 1 && kill $$";
    }
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

1;
