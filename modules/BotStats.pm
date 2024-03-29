package BotStats;

# Shadow Module: BotStats
# This module adds a command which returns stats about this
# instance of Shadow.  Requires bot admin.
#
# COMMAND: /msg <bot> status
#
# Written by Aaron Blakely <aaron@ephasic.org>

use POSIX;
use Time::Seconds;

use Shadow::Core;
use Shadow::Help;

use lib '../lib';
use Shadow::Formatter;

if ($^O eq "linux") {
  require Proc::ProcessTable;
} elsif ($^O eq "msys" || $^O eq "MSWin32") {
  require Win32::OLE;
}

my $LOADTIME = time();
my $bot      = Shadow::Core->new();
my $help     = Shadow::Help->new();

sub loader {
  if ($^O ne "linux" && $^O ne "msys" && $^O ne "MSWin32") {
    print "Error: BotStats module is deisgned for linux or windows systems.\n";
    print "       Some functions might not work as intended on other platforms.\n";
  }

  $bot->register("BotStats", "v1.3", "Aaron Blakely", "Bot status information");
  $bot->add_handler('privcmd status', 'BotStats_dostatus');
  $help->add_help('status', 'Admin', '', 'Outputs current stats about the bot.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02STATUS\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02status\x02 will give you details about the bot such as memory usage, number of channels, and mod count.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick status");
  });

  $bot->add_handler('privcmd hookstats', 'BotStats_hookstats');
  $help->add_help('hookstats', 'Admin', '', 'Outputs events which have hooks attached.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02HOOKSTATS\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02hookstats\x02 will give you details about events which have hooks attached.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick hookstats");
  });
}

sub memusage {
  if ($^O =~ /linux/) {
    my $pid = (defined($_[0])) ? $_[0] : $$;
    my $proc = Proc::ProcessTable->new;
    my %fields = map { $_ => 1 } $proc->fields;
    return undef unless exists $fields{'pid'};
    
    foreach (@{$proc->table}) {
      if ($_->pid eq $pid) {
        return $_->size if exists $fields{'size'};
      };
    };
    
  } elsif ($^O =~ /msys/ || $^O =~ /MSWin32/) {
    my $objWMI = Win32::OLE->GetObject('winmgmts:\\\\.\\root\\cimv2');
    my $processes = $objWMI->ExecQuery("select * from Win32_Process where ProcessId=$$");

    foreach my $proc (in($processes)) {
        return $proc->{WorkingSetSize};
    }
  } else {
    return 0;
  }
}

sub BotStats_dostatus {
  my ($nick, $host, $text) = @_;

  my $fmt = Shadow::Formatter->new();
  $fmt->table_header("Stat", "Value");

  if ($bot->isbotadmin($nick, $host)) {
    my $mem = memusage();
    if ($mem) {
      $mem  = $mem / 1024;
      $mem  = $mem / 1024;
      $mem  = floor($mem);

      $fmt->table_row("Memory", "$mem MB");
    }

    $fmt->table_row("Channel Cnt", scalar(keys(%Shadow::Core::sc)));

    
    my %modlist = $bot->module_stats();

    my $c = 0;
    foreach my $mod (keys %modlist) {
        next if ($mod eq "loadedmodcount");

        if ($mod =~ /Shadow\:\:Mods\:\:/) {
            $c++;
        }
    }

    $fmt->table_row("Module Cnt", $c);
    $fmt->table_row("Servers", join(", ", keys(%Shadow::Core::server)));

    my $uptime = Time::Seconds->new((time() - $^T));
    $fmt->table_row("Uptime", $uptime->pretty);

    $bot->fastsay($nick, $fmt->table());
  } else {
    $bot->notice($nick, "Access denied.");
    $bot->log("BotStats: STATUS command denied for $nick.", "Modules");
  }
}

sub BotStats_hookstats {
  my ($nick, $host, $text) = @_;

  my @out;
  my $fmt = Shadow::Formatter->new();

  my @evHandlers = (
    'event tick', 'event join_me', 'event join', 'event part_me', 'event part', 'event quit', 'event nick_me',
    'event nick', 'event mode', 'event voice_me', 'event halfop_me', 'event op_me', 'event protect_me',
    'event owner_me', 'event ban_me', 'event notice', 'event invite', 'event kick', 'event connected',
    'event nicktaken', 'event topic', 'mode voice', 'mode halfop', 'mode op', 'mode protect', 'mode owner',
    'mode ban', 'mode otherp', 'mode other', 'chancmd default', 'chanmecmd default', 'message channel',
    'message private', 'chancmd *', 'chanmecmd *', 'privcmd *', 'ctcp *'
  );

  my %hooked;

  foreach my $ehandler (@evHandlers) {
    my ($handler, $subhandler) = split(/ /, $ehandler);

    if ($subhandler eq "*") {
      foreach my $subhandlers (keys %{$Shadow::Core::handlers{$handler}}) {
        if (exists $hooked{$ehandler}) {
          $hooked{$ehandler}++;
        } else {
          $hooked{$ehandler} = 1;
        }
      }
    } else {
      if (exists $Shadow::Core::handlers{$handler}{$subhandler}) {
        $hooked{$ehandler} = scalar(@{$Shadow::Core::handlers{$handler}{$subhandler}});
      }
    }
  }

  $fmt->table_header("Class", "Hook", "Count");

  foreach my $hook (keys %hooked) {
    $fmt->table_row((split(/ /, $hook))[0], (split(/ /, $hook))[1], "$hooked{$hook} handlers");
  }

  $bot->fastnotice($nick, $fmt->table());
}

sub unloader {
  $bot->unregister("BotStats");
  $bot->del_handler('privcmd status', 'BotStats_dostatus');
  $bot->del_handler('privcmd hookstats', 'BotStats_hookstats');
  $help->del_help('status', 'Admin');
}

1;
