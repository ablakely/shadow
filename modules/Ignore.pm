package Ignore;

#
# Ignore.pm - Ignore command
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Date: 3/29/2023

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();
my $dbi  = Shadow::DB->new();

sub loader {
    $bot->register("Ignore", "v2.0", "Aaron Blakely", "Ignore users");
    $bot->add_handler('privcmd ignore', 'ignore_add');
    $bot->add_handler('privcmd unignore', 'ignore_del');

    $help->add_help('ignore', 'Admin', '<nick> [host]', 'Ignore a user', 1, sub {
        my ($nick, $host, $text) = @_;
        my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

        $bot->fastsay($nick, (
            "Help for \x02IGNORE\x02:",
            " ",
            "\x02ignore\x02 adds a user to list of users the bot doesn't respond to.",
            " ",
            "\x02SYNTAX\x02: ${cmdprefix}ignore <nick>"
        ));
    });

    $help->add_help('unignore', 'Admin', '<nick>', 'Unignore a user', 1, sub {
        my ($nick, $host, $text) = @_;
        my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

        $bot->fastsay($nick, (
            "Help for \x02UNIGNORE\x02:",
            " ",
            "\x02unignore\x02 removes a user from list of users the bot doesn't respond to.",
            " ",
            "\x02SYNTAX\x02: ${cmdprefix}unignore <nick>"
        ));
    });

    my $db = ${$dbi->read()};
    if ($db->{Ignore}) {
        foreach my $nick (@{$db->{Ignore}}) {
            $bot->add_ignore($nick, "");
        }
    } else {
        $db->{Ignore} = ();

        $dbi->write();
    }
}

sub ignore_add {
    my ($nick, $host, $text) = @_;
    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->notice($nick, "Unauthorized.");
    }

    my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";
    my $db = ${$dbi->read()};

    if (!$text || $text eq "") {
        return $bot->notice($nick, "\002SYNTAX\002: ${cmdprefix}ignore <nick> [host]");
    }

    my ($rnick, $rhost) = split(/ /, $text);

    foreach my $ignores (@{$db->{Ignore}}) {
        if ($rnick eq $ignores || $rhost eq $ignores) {
            $bot->notice($nick, "Already ignoring $rnick [$rhost]");
            return;
        }
    }

    $bot->add_ignore($rnick, $rhost);
    $bot->notice($nick, "Ignoring $rnick [$rhost]");
    $bot->log("Ignoring $rnick ($rhost) [Issued by $nick]", "Modules");

    push(@{$db->{Ignore}}, $rnick);
    if ($rhost ne "") {
        push(@{$db->{Ignore}}, $rhost);
    }

    $dbi->write();
}

sub ignore_del {
    my ($nick, $host, $text) = @_;

    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->notice($nick, "Unauthorized.");
    }

    my ($rnick, $rhost) = split(/ /, $text);

    my $db = ${$dbi->read()};
    my $found = 0;

    for (my $i = 0; $i < scalar(@{$db->{Ignore}}); $i++) {
        if (@{$db->{Ignore}}[$i] eq $rnick || @{$db->{Ignore}}[$i] eq $rhost) {
            splice(@{$db->{Ignore}}, $i, $i+1);
            $found = 1;
        }
    }

    if ($found == 1) {
        $bot->del_ignore($rnick, $rhost);
        $bot->notice($nick, "Unignoring $rnick [$rhost]");
        $bot->log("Unignoring $rnick ($rhost) [Issued by $nick]", "Modules");
    } else {
        $bot->notice($nick, "$rnick ($rhost) is not being ignored.");
        return;
    }

    $dbi->write();
}

sub unloader {
    $bot->unregister("Ignore");
    $bot->del_handler('privcmd ignore', 'ignore_add');
    $bot->del_handler('privcmd unignore', 'ignore_del');

    $help->del_help('ignore', 'Admin');
    $help->del_help('unignore', 'Admin');
}

1;
