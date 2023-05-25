package Welcome;
# Welcome.pm - Basic channel greeting module
#   This is meant to be more of an example of how to write a module
#   for shadow.
# Written by Aaron Blakely <aaron@ephasic.org>
#

use Shadow::Help;
use Shadow::Core;
use Shadow::DB;

my $help = Shadow::Help->new();
my $bot = Shadow::Core->new();
my $dbi = Shadow::DB->new();

# the loader subroutine is automatically called when the module is loaded.
sub loader {
    # register our module
    $bot->register("Welcome", "v0.6", "Aaron Blakely");

    # define handlers for events
    $bot->add_handler('event join', 'welcomeJoinEvent');
    $bot->add_handler('privcmd welcome', 'welcome_manage');

    # add help information to /msg <bot> help
    $help->add_help('welcome', 'Channel', '<chan> <set|del> <greeting>',  "Channel greeting settings", 0, sub {
        my ($nick, $host, $text) = @_;

        # detect if being called from IRC or web terminal
        my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

        my @out;
        push(@out, "Help for \x02Welcome\x02:");
        push(@out, " ");
        push(@out, "\x02welcome\x02 is used to set or remove automatic greetings for a channel.");
        push(@out, "Subcommands:");
        push(@out, "  \x02set\x02 - Set the greeting for a channel.");
        push(@out, "  \x02del\x02 - Removes the greeting for a channel.");
        push(@out, " ");
        push(@out, "Formatting:");
        push(@out, "  \x02\%NICK\%\x02 - Variable for the user's nick.");
        push(@out, "  \x02\%CHAN\%\x02 - Variable for the channel.");
        push(@out, " ");
        push(@out, "\x02SYNTAX\x02: ${cmdprefix}welcome <chan> <set|del> [greeting]");

        # $bot->fastsay() is used instead of $bot->say() to reduce lag from filling the
        # message queue with help messages.
        $bot->fastsay($nick, @out);
    });
}

sub welcome_manage {
    my ($nick, $host, $text) = @_;

    # read the database
    my $db = ${$dbi->read()};

    # process our command arguments
    my @tmp  = split(/ /, $text);
    my $chan = shift(@tmp);
    my $cmd  = shift(@tmp);
    $text = join(" ", @tmp);

    # check user for channel op
    if ($bot->isin($chan, $Shadow::Core::nick) && $bot->isop($nick, $chan)) {
        if ($cmd eq "set") {
            $db->{Welcome}->{$chan} = $text;

            $bot->say($nick, "Set greeting for $chan: $text");
        } elsif ($cmd eq "del") {
            delete $db->{Welcome}->{$chan};

            $bot->say($nick, "Removed greeting for $chan");
        } else {
            return $bot->say($nick, "Unknown subcommand: \x02$cmd\x02");
        }
    } else {
        return $bot->say($nick, "Command requires channel op (+o) mode.");
    }

    # write our changes back to disk
    $dbi->write();
}

sub welcomeJoinEvent {
    my ($nick, $host, $chan) = @_;

    my $db = ${$dbi->read()};

    if ($db->{Welcome}->{$chan}) {
        my $greet = $db->{Welcome}->{$chan};

        # interpolate variables in the greeting
        $greet =~ s/\%NICK\%/$nick/gsi;
        $greet =~ s/\%CHAN\%/$chan/gsi;

        $bot->say($chan, $greet);
    }
}

# unloader is called when the module is unloaded.
sub unloader {
    # unregister the module
    $bot->unregister("Welcome");

    # remove our handlers
    $bot->del_handler('event join', 'welcomeJoinEvent');
    $bot->del_handler('privcmd welcome', 'welcome_manage');

    # remove help topic
    $help->del_help("welcome", "Channel");
}
