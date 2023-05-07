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

if ($^O eq "linux") {
  require Proc::ProcessTable;
} elsif ($^O eq "msys" || $^O eq "MSWin32") {
  require Win32::OLE;
}

my $LOADTIME = time();
my $bot      = Shadow::Core;
my $help     = Shadow::Help;

sub loader {
  if ($^O ne "linux" && $^O ne "msys" && $^O ne "MSWin32") {
    print "Error: BotStats module is deisgned for linux or windows systems.\n";
    print "       Some functions might not work as intended on other platforms.\n";
  }

  $bot->register("BotStats", "v1.2", "Aaron Blakely");
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

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "\x02*** BOT STATUS ***\x02");
    my $mem = memusage();
    if ($mem) {
      $mem  = $mem / 1024;
      $mem  = $mem / 1024;
      $mem  = floor($mem);

      $bot->notice($nick, "Current Memory Usage: $mem MB");
    }

    my $chancount = 0;
    foreach my $m (keys %Shadow::Core::sc) {
      $chancount++;
    }

    $bot->notice($nick, "Currently joined in $chancount channels.");

    my $uptime = Time::Seconds->new((time() - $^T));
    $bot->notice($nick, "Bot Uptime: ".$uptime->pretty);
  } else {
    $bot->notice($nick, "Access denied.");
    $bot->log("BotStats: STATUS command denied for $nick.");
  }
}

sub BotStats_hookstats {
  my ($nick, $host, $text) = @_;

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

  $bot->notice($nick, "\x02---[ Hooked Event Handlers ]---\x02");
  foreach my $hook (keys %hooked) {
    $bot->notice($nick, "\x02$hook\x02 - Count: $hooked{$hook}");
  }
  $bot->notice($nick, "-------------------------------");
}

sub unloader {
  $bot->unregister("BotStats");
  $bot->del_handler('privcmd status', 'BotStats_dostatus');
  $bot->del_handler('privcmd hookstats', 'BotStats_hookstats');
  $help->del_help('status', 'Admin');
}

1;
