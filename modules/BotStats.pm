package BotStats;

use POSIX;
use Time::Seconds;
use Proc::ProcessTable;

my $LOADTIME = time();
my $bot      = Shadow::Core;
my $help     = Shadow::Help;

sub loader {
  if ($^O !~ /linux/) {
    print "Error: BotStats module is deisgned for linux systems.\n";
    print "       Some functions might not work as intended on other platforms.\n";
    return;
  }

  $bot->add_handler('privcmd status', 'BotStats_dostatus');
  $help->add_help('status', 'Admin', '', 'Outputs current stats about the bot.');
}

sub memusage {
    my $pid = (defined($_[0])) ? $_[0] : $$;
    my $proc = Proc::ProcessTable->new;
    my %fields = map { $_ => 1 } $proc->fields;
    return undef unless exists $fields{'pid'};
    foreach (@{$proc->table}) {
        if ($_->pid eq $pid) {
            return $_->size if exists $fields{'size'};
        };
    };
    return 0;
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
  }
}

sub unloader {
  $bot->del_handler('privcmd status', 'BotStats_dostatus');
  $help->del_help('status', 'Admin');
}

1;
