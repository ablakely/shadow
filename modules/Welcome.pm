package Welcome;

my $bot = Shadow::Core;

sub loader {
    $bot->add_handler('event join', 'welcomeJoinEvent');
}

sub welcomeJoinEvent {
    my ($nick, $host, $chan) = @_;

    $bot->say($chan, "Welcome $nick, to $chan enjoy your visit!");
}

sub unloader {
    $bot->del_handler('event join', 'welcomeJoinEvent');
}