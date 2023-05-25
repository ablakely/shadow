package Aliases;

# Aliases.pm - Custom Response Triggers
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Date: 6/7/2022

use JSON;
use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();
my $dbfile = "./etc/aliases.db";

sub loader {
    $bot->register("Aliases", "v1.0", "Aaron Blakely", "Custom response triggers");

    $bot->add_handler('privcmd alias', 'aliasHandler');
    $bot->add_handler('message channel', 'chanMessageHandler');

    if (!-e $dbfile) {
      $bot->log("Aliases: No alias database found, creating one.", "Modules");
      open(my $db, ">", $dbfile) or $bot->error("Aliases: Error: Couldn't open $dbfile: $!", 0, "Modules");
      print $db "{}";
      close($db);
    }
}

sub _dbread {
  my @dbread;
  my $jsonstr;

  open(my $db, "<", $dbfile) or $bot->err("Aliases: Error: Couldn't open $dbfile: $!", 0, "Modules");
  while (my $line = <$db>) {
    chomp $line;
    $jsonstr .= $line;
  }
  close($db);

  return from_json($jsonstr, { utf8 => 1 });
}

sub _dbwrite {
  my ($data) = @_;
  my $jsonstr = to_json($data, { utf8 => 1, pretty => 1 });

  open(my $db, ">", $dbfile) or $bot->err("Aliases: Error: Couldn't open $dbfile: $!",  0, "Modules");
  print $db $jsonstr;
  close($db);
}

sub aliasHandler {
    my ($nick, $host, $text) = @_;

    my @cmdSplit = split(" ", $text);
    my $db = _dbread();

    if ($cmdSplit[0] eq "add" || $cmdSplit[0] eq "ADD") {
        if (!$cmdSplit[1] || !$cmdSplit[2] || !$cmdSplit[3]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias add <chan> <trigger> <response>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            my @cmdSplitCopy = @cmdSplit;
            $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} = join(" ", splice(@cmdSplitCopy, 3, $#cmdSplit));
            _dbwrite($db);
            $bot->notice($nick, "Added alias !".$cmdSplit[2].": ".$db->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Added alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.", "Modules");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: ADD $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]", "Modules");
        }

    } elsif ($cmdSplit[0] eq "del" || $cmdSplit[0] eq "DEL") {
        if (!$cmdSplit[1] || !$cmdSplit[2]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias del <chan> <trigger>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            $bot->notice($nick, "Alias deleted !$cmdSplit[2]");
            $bot->log("Aliases: Deleted alias for channel $cmdSplit[1]: !$cmdSplit[2] (response: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]})", "Modules");

            delete $db->{lc($cmdSplit[1])}->{$cmdSplit[2]};
            _dbwrite($db);
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: DEL $cmdSplit[1] $cmdSplit[2]", "Modules");
        }
    } elsif ($cmdSplit[0] eq "update" || $cmdSplit[0] eq "UPDATE") {
        if (!$cmdSplit[1] || !$cmdSplit[2] || !$cmdSplit[3]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias update <chan> <trigger> <response>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            my @cmdSplitCopy = @cmdSplit;
            $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} = join(" ", splice(@cmdSplitCopy, 3, $#cmdSplit));
            _dbwrite($db);
            $bot->notice($nick, "Updated alias !".$cmdSplit[2].": ".$db->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Updated alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.", "Modules");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: UPDATE $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]", "Modules");
        }

    } elsif ($cmdSplit[0] eq "list" || $cmdSplit[0] eq "LIST") {
        if (!$cmdSplit[1]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias list <chan>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            $bot->notice($nick, "---[ Aliases for $cmdSplit[1] ]---");
            foreach my $trigger (keys %{$db->{lc($cmdSplit[1])}}) {
                $bot->notice($nick, "!$trigger - $db->{lc($cmdSplit[1])}->{$trigger}");
            }
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: LIST $cmdSplit[1]", "Modules");
        }
    } else {
        return $bot->notice($nick, "\002Syntax:\002 alias [add|del|update|list] <channel> <trigger> (response)");
    }
}

sub chanMessageHandler {
    my ($nick, $host, $chan, $text) = @_;

    if ($text =~ /^\!\E(\S+)(\s+(.*))?/) {
        my $db = _dbread();

        if (exists($db->{$chan}->{$1})) {
            $bot->say($chan, $db->{lc($chan)}->{$1});
        }
    }

}

sub unloader {
    $bot->unregister("Aliases");
    $bot->del_handler('privcmd alias', 'aliasHandler');
    $bot->del_handler('message channel', 'chanMessageHandler');
}

1;
