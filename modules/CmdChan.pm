package CmdChan;
# CmdChan - Autokicks non bot admins from logging channel
#
# Written by Aaron Blakely <aaron@ephasic.org>
#

use Shadow::Core;

my $bot = Shadow::Core->new();

my $cmdchan = $Shadow::Core::cfg->{Shadow}->{IRC}->{bot}->{cmdchan};


sub loader {
    $bot->register("CmdChan", "v0.5", "Aaron Blakely", "Autokicks non botadmins from logging channel.");
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
    $bot->unregister("CmdChan");
    $bot->del_handler('event join', "checkAdminJoin");
}

1;
