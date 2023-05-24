package Welcome;
# Welcome.pm - Basic channel greeting module
#   This is meant to be more of an example of how to write a module
#   for shadow.
# Written by Aaron Blakely <aaron@ephasic.org>
#

use Shadow::Core;

my $bot = Shadow::Core->new();

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
