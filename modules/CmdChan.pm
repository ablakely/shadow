package CmdChan;

my $bot = Shadow::Core;
my $cmdchan = $Shadow::Core::cfg->{Shadow}->{IRC}->{bot}->{cmdchan};

sub loader {
    $bot->add_handler('event join', "checkAdminJoin");
}


sub checkAdminJoin {
    my ($nick, $hostmask, $chan) = @_;

    if ($chan eq $cmdchan) {
        if (!$bot->isbotadmin($nick, $host)) {
            $bot->kick($chan, $nick, "Bot Admins only");
        }
    }
}

sub unloader {
    $bot->del_handler('event join', "checkAdminJoin");
}

1;