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
  use Proc::ProcessTable;
} elsif ($^O eq "msys") {
  use Win32::OLE qw/in/;
}

my $LOADTIME = time();
my $bot      = Shadow::Core;
my $help     = Shadow::Help;

sub loader {
  if ($^O !~ /linux/ || $^O !~ /msys/) {
    print "Error: BotStats module is deisgned for linux or windows systems.\n";
    print "       Some functions might not work as intended on other platforms.\n";
  }

  $bot->add_handler('privcmd status', 'BotStats_dostatus');
  $help->add_help('status', 'Admin', '', 'Outputs current stats about the bot.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02STATUS\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02status\x02 will give you details about the bot such as memory usage, number of channels, and mod count.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick status");
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
    
  } elsif ($^O =~ /msys/) {
    print "win32\n";
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
      if ($^O eq "linux") {
        $mem  = $mem / 1024;
        $mem  = $mem / 1024;
        $mem  = floor($mem);
      }

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

sub unloader {
  $bot->del_handler('privcmd status', 'BotStats_dostatus');
  $help->del_help('status', 'Admin');
}

1;
