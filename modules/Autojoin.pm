package Autojoin;

# Shadow Module: Autojoin
# Module that implements an autojoin feature, which is a list of channels
# to automatically join on connect that is manipulated via IRC commands.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;

my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();
my $dbi  = Shadow::DB->new();
my $web;

sub aj_webmod_init {
    return unless (shift() eq "WebAdmin");

    if ($bot->isloaded("WebAdmin")) {
        $web = WebAdmin->new();
        my $router = $web->router();

        $web->add_navbar_link("/autojoin", "hash", "Auto Join");
        $router->get('/autojoin', sub {
            my ($client, $params, $headers) = @_;

            if ($web->checkSession($headers)) {
                my $db = ${$dbi->read()};

                if (exists($params->{delInputChan})) {
                    $params->{delInputChan} = '#'.$params->{delInputChan};

                    if (exists($db->{Autojoin}->{$params->{delInputChan}})) {
                        delete $db->{Autojoin}->{$params->{delInputChan}};

                        if ($bot->isin($params->{delInputChan}, $Shadow::Core::nick)) {
                            $bot->part($params->{delInputChan}, "Removed from autojoin.");
                        }

                        $dbi->write();
                    }

                    $dbi->free();
                    return $router->redirect($client, "/autojoin");
                } elsif (exists($params->{addInputChan}) && exists($params->{addInputKey})) {
                    $params->{addInputChan} = '#'.$params->{addInputChan};

                    if (!exists($db->{Autojoin}->{$params->{addInputChan}})) {
                        $db->{Autojoin}->{$params->{addInputChan}} = $params->{addInputKey} ? $params->{addInputKey} : "";

                        if (!$bot->isin($params->{addInputChan}, $Shadow::Core::nick)) {
                            $bot->join($params->{addInputChan}, $db->{Autojoin}->{$params->{addInputChan}});
                        }

                        $dbi->write();
                    }

                    $dbi->free();
                    return $router->redirect($client, "/autojoin");
                } elsif (exists($params->{csInputChan}) && exists($params->{csInputKey})) {
                    $params->{csInputChan} = '#'.$params->{csInputChan};

                    if (exists($db->{Autojoin}->{$params->{csInputChan}})) {
                        $db->{Autojoin}->{$params->{csInputChan}} = $params->{csInputKey} ? $params->{csInputKey} : "";

                        if (!$bot->isin($params->{csInputChan}, $Shadow::Core::nick)) {
                            $bot->join($params->{csInputChan}, $db->{Autojoin}->{$params->{csInputChan}});
                        }

                        $dbi->write();
                    }

                    $dbi->free();
                    return $router->redirect($client, "/autojoin");
                } else {
                    my @chankeys = sort(keys(%{$db->{Autojoin}}));

                    $router->headers($client);
                    $web->out($client, $web->render("mod-autojoin/index.ejs", {
                        nav_active => "Auto Join",
                        chankeys => \@chankeys,
                        db => $db->{Autojoin}
                    }));

                    $dbi->free();
                }
            } else {
                return $router->redirect($client, "/");
            }
        });
    }
}

sub aj_webmod_cleanup {
    return unless (shift() eq "WebAdmin");

    if ($bot->isloaded("WebAdmin")) {
        my $router = $web->router();
        $web->del_navbar_link("Auto Join");

        $router->del('get', '/autojoin');
    }
}

sub loader {
    $bot->register("Autojoin", "v2.0", "Aaron Blakely", "Autojoin channels");
    $bot->add_handler('event connected', 'Autojoin_connected');
    $bot->add_handler('privcmd autojoin', 'autojoin');

    $help->add_help('autojoin', 'Admin', '<add|del|list> <chan> [key]', 'Shadow Autojoin Module', 0, sub {
            my ($nick, $host, $text) = @_;

            my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

            $bot->fastsay($nick, (
                    "Help for \x02AUTOJOIN\x02:",
                    " ",
                    "\x02autojoin\x02 is a command for managing which channels the bot automatically joins on connect.",
                    "This command uses a set of subcommands to perform actions:",
                    "  \x02add\x02 - Adds a channel to the autojoin list.",
                    "  \x02del\x02 - Removes a channel from the autojoin list.",
                    "  \x02list\x02 - Lists all the channels the bot automatically joins.",
                    " ",
                    "\x02SYNTAX\x02: ${cmdprefix}autojoin <add|del|list> [chan] [key]"
                ));
        });


    $bot->add_handler('module load', 'aj_webmod_init');
    $bot->add_handler('module reload', 'aj_webmod_init');
    $bot->add_handler('module unload', 'aj_webmod_cleanup');
    aj_webmod_init("WebAdmin");

    my $db = ${$dbi->read()};
    if (!exists($db->{Autojoin})) {
        $db->{Autojoin} = {};
        $dbi->write();
    }
    $dbi->free();
}

sub Autojoin_connected {
    my $db = ${$dbi->read()}; 

    foreach my $chan (keys %{$db->{Autojoin}}) {
        $bot->join($chan);
    }

    $dbi->free();
}

sub autojoin {
    my ($nick, $host, $text) = @_;
    my ($cmd, $chan, $key) = split(" ", $text);

    if ($bot->isbotadmin($nick, $host)) {
        my $db = ${$dbi->read()};

        if (!$cmd) {
            $dbi->free();
            return $bot->notice($nick, "Syntax: autojoin <add|del|list> <channel> [key]");
        }

        if ($cmd eq "add") {
            $db->{Autojoin}->{$chan} = $key;

            $bot->join($chan);
            $bot->notice($nick, "Added $chan to auto join list.");
        } elsif ($cmd eq "del") {
            if (!$db->{Autojoin}->{$chan}) {
                $dbi->free();
                return $bot->notice($nick, "$chan is not in autojoin list");
            }
            delete $db->{Autojoin}->{$chan};

            $bot->part($chan, "Removed from autojoin.");
            $bot->notice($nick, "Removed $chan from auto join list.")
        } elsif ($cmd eq "list") {
            my $fmt = Shadow::Formatter->new();

            $fmt->table_header("Channel", "Key");

            foreach my $chan (keys %{$db->{Autojoin}}) {
                $fmt->table_row($chan, $db->{Autojoin}->{$chan});
            }

            $bot->fastnotice($nick, $fmt->table());
        }

        $dbi->write();
    }
}

sub unloader {
    $bot->unregister("Autojoin");
    $bot->del_handler('event connected', 'Autojoin_connected');
    $bot->del_handler('privcmd autojoin', 'autojoin');

    $help->del_help('autojoin', 'Admin');

    $bot->del_handler('module load', 'aj_webmod_init');
    $bot->del_handler('module reload', 'aj_webmod_init');
    $bot->del_handler('module unload', 'aj_webmod_cleanup');

    aj_webmod_cleanup("WebAdmin");

    $dbi->free();
}

1;
