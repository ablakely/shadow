package Aliases;

# Aliases.pm - Custom Response Triggers
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Date: 6/7/2022

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;

my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();
my $dbi  = Shadow::DB->new();

sub loader {
    $bot->register("Aliases", "v2.0", "Aaron Blakely", "Custom response triggers");

    $bot->add_handler('privcmd alias', 'aliasHandler');
    $bot->add_handler('message channel', 'chanMessageHandler');

    $help->add_help(
        'alias',
        'Channel',
        '<add|del|update|list> <chan> <trigger> [response]',
        'Custom response triggers for channels',
        0,
        sub {
            my ($nick, $host, $text) = @_;
            my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

            $bot->fastsay($nick, (
                "Help for \x02ALIAS\x02:",
                " ",
                "\x02alias\x02 is used to allow custom responses to trigger commands (ex: !cmd)",
                "\x02Subcommands\x02:",
                "  \x02add\x02 - Adds a new alias",
                "  \x02del\x02 - Removes an alias",
                "  \x02update\x02 - Changes the resonse of an alias",
                "  \x02list\x02 - Lists aliases for a channel",
                " ",
                "\x02SYNTAX\x02: ${cmdprefix}alias <add|del|update|list> <chan> <trigger> [response]"
            ));
        }
    );


    my $db = ${$dbi->read()};
    if (!$db->{Aliases}) {
        $db->{Aliases} = {};
    
        $dbi->write();
    }
}

sub aliasHandler {
    my ($nick, $host, $text) = @_;

    my @cmdSplit = split(" ", $text);
    my $db = ${$dbi->read()};
    my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

    if ($cmdSplit[0] eq "add" || $cmdSplit[0] eq "ADD") {
        if (!$cmdSplit[1] || !$cmdSplit[2] || !$cmdSplit[3]) {
            $dbi->free();
            return $bot->notice($nick, "\002Syntax\002: ${cmdprefix}alias add <chan> <trigger> <response>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            my @cmdSplitCopy = @cmdSplit;
            $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]} = join(" ", splice(@cmdSplitCopy, 3, scalar(@cmdSplit)));

            $bot->notice($nick, "Added alias !".$cmdSplit[2].": ".$db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Added alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.", "Modules");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: ADD $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]", "Modules");
        }

    } elsif ($cmdSplit[0] eq "del" || $cmdSplit[0] eq "DEL") {
        if (!$cmdSplit[1] || !$cmdSplit[2]) {
            $dbi->free();
            return $bot->notice($nick, "\002Syntax\002: ${cmdprefix}alias del <chan> <trigger>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            $bot->notice($nick, "Alias deleted !$cmdSplit[2]");
            $bot->log("Aliases: Deleted alias for channel $cmdSplit[1]: !$cmdSplit[2] (response: $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]})", "Modules");

            delete $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]};
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: DEL $cmdSplit[1] $cmdSplit[2]", "Modules");
        }
    } elsif ($cmdSplit[0] eq "update" || $cmdSplit[0] eq "UPDATE") {
        if (!$cmdSplit[1] || !$cmdSplit[2] || !$cmdSplit[3]) {
            $dbi->free();
            return $bot->notice($nick, "\002Syntax\002: /msg ${cmdprefix}alias update <chan> <trigger> <response>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            my @cmdSplitCopy = @cmdSplit;
            $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]} = join(" ", splice(@cmdSplitCopy, 3, scalar(@cmdSplit)));

            $bot->notice($nick, "Updated alias !".$cmdSplit[2].": ".$db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]});
            $bot->log("Aliases: Updated alias for channel $cmdSplit[1] !$cmdSplit[2]: $db->{Aliases}->{lc($cmdSplit[1])}->{$cmdSplit[2]} by $nick.", "Modules");
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: UPDATE $cmdSplit[1] $cmdSplit[2] :$cmdSplit[3]", "Modules");
        }

    } elsif ($cmdSplit[0] eq "list" || $cmdSplit[0] eq "LIST") {
        if (!$cmdSplit[1]) {
            $dbi->free();
            return $bot->notice($nick, "\002Syntax\002: /msg ${cmdprefix}alias list <chan>");
        }

        if ($bot->isin($cmdSplit[1], $Shadow::Core::nick) && $bot->isop($nick, $cmdSplit[1])) {
            if (!scalar(keys(%{$db->{Aliases}->{lc($cmdSplit[1])}}))) {
                $dbi->free();
                return $bot->notice($nick, "No aliases exist for $cmdSplit[1]");
            }

            my $fmt = Shadow::Formatter->new();
            $fmt->table_header("Trigger", "Response");

            foreach my $trigger (keys %{$db->{Aliases}->{lc($cmdSplit[1])}}) {
                $fmt->table_row("!$trigger", $db->{Aliases}->{lc($cmdSplit[1])}->{$trigger});
            }
            
            $bot->fastsay($nick, $fmt->table());
        } else {
            $bot->notice($nick, "Command requires channel op (+o) mode.");
            $bot->log("Aliases: Command denied for $nick: LIST $cmdSplit[1]", "Modules");
        }
    } else {
        $dbi->free();
        return $bot->notice($nick, "\002Syntax\002: ${cmdprefix}alias <add|del|update|list> <channel> <trigger> [response]");
    }

    $dbi->write()
}

sub chanMessageHandler {
    my ($nick, $host, $chan, $text) = @_;

    if ($text =~ /^\!\E(\S+)(\s+(.*))?/) {
        my $db = ${$dbi->read()};

        if (exists($db->{Aliases}->{$chan}->{$1})) {
            $bot->say($chan, $db->{Aliases}->{lc($chan)}->{$1});
        }

        $dbi->free();
    }

}

sub unloader {
    $bot->unregister("Aliases");
    
    $bot->del_handler('privcmd alias', 'aliasHandler');
    $bot->del_handler('message channel', 'chanMessageHandler');

    $help->del_help('alias', 'Channel');

    $dbi->free();
}

1;
