package Aliases;

# Aliases.pm - Custom Response Triggers
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Date: 6/7/2022

use JSON;

my $bot = Shadow::Core;
my $help = Shadow::Help;
my $dbfile = "./etc/aliases.db";

sub loader {
    $bot->add_handler('privcmd alias', 'aliasHandler');
    $bot->add_handler('message channel', 'chanMessageHandler');
}

sub _dbread {
  my @dbread;
  my $jsonstr;

  open(my $db, "<", $dbfile) or $bot->err("RSS: Error: Couldn't open $dbfile: $!");
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

  open(my $db, ">", $dbfile) or $bot->err("RSS: Error: Couldn't open $dbfile: $!");
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
            $bot->notice($nick, "Added alias for !".$cmdSplit[2].": ".$db->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Added alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: ADD $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]");
        }

    } elsif ($cmdSplit[0] eq "del" || $cmdSplit[0] eq "DEL") {
        if (!$cmdSplit[1] || !$cmdSplit[2]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias del <chan> <trigger>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            $bot->notice($nick, "Alias deleted for !$cmdSplit[2]");
            $bot->log("Aliases: Deleted alias for channel $cmdSplit[1]: !$cmdSplit[2] (response: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]})");

            delete $db->{lc($cmdSplit[1])}->{$cmdSplit[2]};
            _dbwrite($db);
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: DEL $cmdSplit[1] $cmdSplit[2]");
        }
    } elsif ($cmdSplit[0] eq "update" || $cmdSplit[0] eq "UPDATE") {
        if (!$cmdSplit[1] || !$cmdSplit[2] || !$cmdSplit[3]) {
            return $bot->notice($nick, "\002Syntax\002: /msg $Shadow::Core::nick alias update <chan> <trigger> <response>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            my @cmdSplitCopy = @cmdSplit;
            $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} = join(" ", splice(@cmdSplitCopy, 3, $#cmdSplit));
            _dbwrite($db);
            $bot->notice($nick, "Updated alias for !".$cmdSplit[2].": ".$db->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Updated alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: UPDATE $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]");
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
            $bot->log("Aliases: Command denied for $nick: LIST $cmdSplit[1]");
        }
    } else {
        return $bot->notice($nick, "\002Syntax:\002 alias [add|del|update|list] <trigger> (response)");
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
    $bot->del_handler('privcmd alias', 'aliasHandler');
    $bot->del_handler('message channel', 'chanMessageHandler');
}

1;