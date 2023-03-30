package Ignore;

#
# Ignore.pm - Ignore command
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Date: 3/29/2023

use JSON;

my $bot = Shadow::Core;
my $help = Shadow::Help;
my $dbfile = "./etc/ignore.db";

sub loader {
    $bot->add_handler('privcmd ignore', 'ignore_add');
    $bot->add_handler('privcmd unignore', 'ignore_del');

    if (!-e $dbfile) {
        $bot->log("Ignore: No ignore database found, creating one.");
        open(my $db, ">", $dbfile) or $bot->error("Ignore: Error: Couldn't open $dbfile: $!");
        print $db "[]";
        close($db);
    } else {
        my $db = _dbread();

        foreach my $ignores (@{$db}) {
            $bot->add_ignore($ignores, "");
        }
    }
}

sub _dbread {
    my $jsonstr;

    open(my $db, "<", $dbfile) or $bot->err("Ignore: Error: Couldn't open $dbfile: $!");
    while (my $line = <$db>) {
        chomp $line;
        $jsonstr .= $line;
    }
    close($db);

    return from_json($jsonstr, { utf8 => 1 });
}

sub _dbwrite {
    my ($data) = @_;
    my $jsonstr = to_json($data, { utf8 => 1, pretty => 1});

    open(my $db, ">", $dbfile) or $bot->err("Ignore: Error: Couldn't open $dbfile: $!");
    print $db $jsonstr;
    close($db);
}

sub ignore_add {
    my ($nick, $host, $text) = @_;
    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->notice($nick, "Unauthorized.");
    }

    my $db = _dbread();

    if (!$text || $text eq "") {
        return $bot->notice($nick, "\002SYNTAX\002: /msg $Shadow::Core::nick ignore <nick> [host]");
    }

    my ($rnick, $rhost) = split(/ /, $text);

    foreach my $ignores (@{$db}) {
        if ($rnick eq $ignores || $rhost eq $ignores) {
            $bot->notice($nick, "Already ignoring $rnick [$rhost]");
            return;
        }
    }

    $bot->add_ignore($rnick, $rhost);
    $bot->notice($nick, "Ignoring $rnick [$rhost]");
    $bot->log("Ignoring $rnick ($rhost) [Issued by $nick]");

    push(@{$db}, $rnick);
    if ($rhost ne "") {
        push(@{$db}, $rhost);
    }

    _dbwrite($db);
}

sub ignore_del {
    my ($nick, $host, $text) = @_;

    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->notice($nick, "Unauthorized.");
    }

    my ($rnick, $rhost) = split(/ /, $text);

    my $db = _dbread();
    my $found = 0;

    for (my $i = 0; $i < scalar(@{$db}); $i++) {
        if (@{$db}[$i] eq $rnick || @{$db}[$i] eq $rhost) {
            splice(@{$db}, $i, $i+1);
            $found = 1;
        }
    }

    if ($found == 1) {
        $bot->del_ignore($rnick, $rhost);
        $bot->notice($nick, "Unignoring $rnick [$rhost]");
        $bot->log("Unignoring $rnick ($rhost) [Issued by $nick]");
    } else {
        $bot->notice($nick, "$rnick ($rhost) is not being ignored.");
        return;
    }

    _dbwrite($db);
}

sub unloader {
    $bot->del_handler('privcmd ignore', 'ignore_add');
    $bot->del_handler('privcmd unignore', 'ignore_del');
}

1;