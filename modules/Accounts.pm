package Accounts;
# Accounts - User accounts module
#
# Written by Aaron Blakely <aaron@ephasic.org>

use Digest::SHA qw(sha256_hex);

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;

my %sessions;

my $dbi  = Shadow::DB->new();
my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();
my $web;

# Public methods
sub new {
    return shift();  # return Accounts class
}

sub is_authed {
    my ($self, $nick) = @_;

    if (exists($sessions{$nick})) {
        return 1;
    }

    return 0;
}

sub acc_exists {
    my ($self, $nick) = @_;

    my $db = ${$dbi->read("accounts.db")};

    if (exists($db->{$nick})) {
        $dbi->free();

        return 1;
    }

    $dbi->free();

    return 0;
}

sub get_account_prop {
    my ($self, $nick, $prop) = @_;

    my $db = ${$dbi->read("accounts.db")};

    if (exists($db->{$nick}->{$prop})) {
        my $prop = $db->{$nick}->{$prop};
        $dbi->free();

        return $prop;
    }

    $dbi->free();

    return undef;
}

sub set_account_prop {
    my ($self, $nick, $prop, $val) = @_;

    my $db = ${$dbi->read("accounts.db")};
    $db->{$nick}->{$prop} = $val;

    return $dbi->write();
}

sub get_db {
    my ($self, $nick) = @_;
    my $db = ${$dbi->read("accounts.db")};

    return $db->{$nick} ? $db->{$nick} : undef;
}

sub get_session {
    my ($self, $nick) = @_;

    return $session{$nick} ? $session{$nick} : undef;
}

# Private

sub acc_webmod_init {
    # module load and module unload handler will call this for every event,
    # return unless the module for the event is WebAdmin.
    return unless (shift() eq "WebAdmin");

    if ($bot->isloaded("WebAdmin")) {
        $web = WebAdmin->new();
        my $router = $web->router();  
        
        $web->add_navbar_link("/accounts", "users", "Accounts");
        $router->get('/accounts', sub {
            my ($client, $params, $headers, $buf) = @_;
            my $db     = ${$dbi->read("accounts.db")};
            my @dbk    = keys(%{$db});
            
            if ($web->checkSession($headers)) {
                if (exists($params->{view})) {
                    if (exists($db->{$params->{view}})) {
                        my $modinfo = {};

                        foreach my $k (keys(%{$db})) {
                            if ($k eq $params->{view}) {
                                foreach my $key (keys(%{$db->{$k}})) {
                                    if ($key =~ /(.*?)\.(.*)/) {
                                        $modinfo->{$key} = $db->{$k}->{$key};
                                    }
                                }
                            }

                            $db->{$k}->{ctime} = "".gmtime($db->{$k}->{ctime})." GMT";
                            
                            if (exists($db->{$k}->{ltime})) {
                                $db->{$k}->{ltime} = "".gmtime($db->{$k}->{ltime})." GMT";
                            }

                            # online status
                            $db->{$k}->{status} = exists($sessions{$k}) ? "Online" : "Offline";
                        }
                        @dbk = keys(%{$db->{$params->{view}}});
                        my @modk = keys(%{$modinfo});

                        $router->headers($client);
                        $dbi->free();
                        return $web->out($client, $web->render("mod-accounts/view.ejs", {
                            nav_active => "Accounts",
                            acc => $params->{view},
                            db => $db->{$params->{view}},
                            dbk => \@dbk,
                            modinfo => $modinfo,
                            modk => \@modk
                        }));
                    } else {
                        $dbi->free();
                        return $router->redirect($client, "/accounts");
                    }
                } elsif (exists($params->{delete})) {
                    if (exists($db->{$params->{delete}})) {
                        delete $db->{$params->{delete}};

                        $dbi->write();
                        return $router->redirect($client, "..", $headers);
                    } else {
                        $dbi->free();
                        return $router->redirect($client, "/accounts");
                    }
                } elsif (exists($params->{toggleadmin})) {
                    if (exists($db->{$params->{toggleadmin}})) {
                        $db->{$params->{toggleadmin}}->{admin} = $db->{$params->{toggleadmin}}->{admin} == 1 ? 0 : 1;

                        $dbi->write();
                    }
                    return $router->redirect($client, "..", $headers);
                } else {
                    $router->headers($client);
                    foreach my $k (keys(%{$db})) {
                        $db->{$k}->{ctime} = "".gmtime($db->{$k}->{ctime})." GMT";
                        $db->{$k}->{status} = exists($sessions{$k}) ? "Online" : "Offline";
                        if (exists($db->{$k}->{ltime})) {
                            $db->{$k}->{ltime} = "".gmtime($db->{$k}->{ltime})." GMT";
                        }  
                    }
                    
                    $dbi->free();
                    return $web->out($client, $web->render("mod-accounts/index.ejs", {
                        nav_active => "Accounts",
                        db => $db,
                        dbk => \@dbk
                    }));
                }
            } else {
                $dbi->free();
                $router->redirect($client, "/");
            }

            $dbi->free();
        });

        $router->post('/accounts/resetpw', sub {
            my ($client, $params, $headers, $buf) = @_;
            my $db     = ${$dbi->read("accounts.db")};

            if ($web->checkSession($headers)) {
                if (exists($params->{nick}) && exists($params->{password})&& exists($db->{$params->{nick}})) {
                    my $nick  = $params->{nick};
                    my $ctime = $db->{$nick}->{ctime};
                    $db->{$nick}->{password} = hashpw("$nick:$ctime", $params->{password});
                    $dbi->write();
                }
                
                $dbi->free();
                return $router->redirect($client, "/accounts");
            } else {
                $dbi->free();
                return $router->redirect($client, "/");
            }

            $dbi->free();
        });
    }
}

sub acc_webmod_cleanup {
    return unless (shift() eq "WebAdmin");

    if ($bot->isloaded("WebAdmin")) {
        my $router = $web->router();

        $web->del_navbar_link("Accounts");
        $router->del('get', '/accounts');
        $router->del('post', '/accounts/resetpw');
    }
}

sub loader {
    $bot->register("Accounts", "v0.1", "Aaron Blakely", "User Accounts");

    if ($bot->storage_exists("accounts.sessions")) {
        %sessions = %{$bot->retrieve("accounts.sessions")};
    }

    $bot->add_handler("privcmd register", "acc_register");
    $bot->add_handler("privcmd id", "acc_id");
    $bot->add_handler("event quit", "acc_quit_ev");
    $bot->add_handler("privcmd accounts", "acc_admin_interface");
    $bot->add_handler("privcmd passwd", "acc_passwd");


    $bot->add_handler('module load',   'acc_webmod_init');
    $bot->add_handler('module reload', 'acc_webmod_init');
    $bot->add_handler('module unload', 'acc_webmod_cleanup');

    $help->add_help("register", "General", "<password>", "Register an account.", 0, sub {
        my ($nick, $host, $text) = @_;
        $bot->fastsay($nick, (
            "Help for \x02REGISTER\x02:",
            " ",
            "\x02register\x02 is used to create a new account.",
            " ",
            "\x02SYNTAX\x02: ".$help->cmdprefix($nick)."register <password>"
        ));
    });
    
    $help->add_help("id", "General", "[<nick>] <password>", "Log in to an account.", 0, sub {
        my ($nick, $host, $text) = @_;
        $bot->fastsay($nick, (
            "Help for \x02ID\x02:",
            " ",
            "\x02id\x02 is used to login to an account, if \x02<nick>\x02 is omitted the IRC nickname is used in it's place.",
            " ",
            "\x02SYNTAX\x02: ".$help->cmdprefix($nick)."id [<nick>] <password>"
        ));
    });

    $help->add_help("passwd", "General", "<password>", "Change password for an account.", 0, sub {
        my ($nick, $host, $text) = @_;
        $bot->fastsay($nick, (
            "Help for \x02PASSWD\x02:",
            " ",
            "\x02passwd\x02 is used to update a password for an account.",
            " ",
            "\x02SYNTAX\x02: ".$help->cmdprefix($nick)."passwd <password>"
        ));
    });
    
    $help->add_help("accounts", "Admin", "<subcommand> [<args>]", "User Accounts management", 1, sub {
        my ($nick, $host, $text) = @_;
        $bot->fastsay($nick, (
            "Help for \x02ACCOUNTS\x02:",
            " ",
            "\x02accounts\x02 is used to manage user created accounts.",
            "Subcommands:",
            "  \x02list\x02 - Lists all accounts",
            "  \x02remove <nick>\x02 - Deletes an account and it's referenced data",
            "  \x02whois <nick>\x02 - Fetches useful information about an account",
            "  \x02passwd <nick> <pass>\x02 - Force changes a users password",
            " ",
            "\x02SYNTAX\x02: ".$help->cmdprefix($nick)."accounts <subcommand> [<args>]"
        ));
    });

    my $db = ${$dbi->read("accounts.db")};
    if (!scalar(keys(%{$db}))) {
        $dbi->write();
    }

    acc_webmod_init("WebAdmin");
}

sub hashpw {
    my ($salt, $pass) = @_;

    $salt = sha256_hex($salt);
    return sha256_hex($salt.$pass.$salt);
}

sub acc_register {
    my ($nick, $host, $text) = @_;
    
    if ($bot->is_term_user($nick)) {
        return $bot->say($nick, "Account registration is only available over IRC.");
    }

    if (!$text) {
        return $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick register <password>");
    }

    if ($db->{$nick}) {
        return $bot->say($nick, "Account already exists for $nick.");
    }

    my $db = ${$dbi->read("accounts.db")};
    my $ctime = time();

    $db->{$nick} = {};
    $db->{$nick}->{ctime}    = time();
    $db->{$nick}->{password} = hashpw("$nick:$ctime", $text); # sha256_hex($salt.$text.$salt);
    $db->{$nick}->{admin} = $bot->isbotadmin($nick, $host) ? 1 : 0;
    $db->{$nick}->{ltime} = time();
    $db->{$nick}->{lhost} = $host;

    $sessions{$nick} = {
        host => $host,
        account => $nick
    };

    $bot->notice($nick, "Account created for $nick");
    $dbi->write();
}

sub acc_id {
    my ($nick, $host, $text) = @_;

    my ($inputNick, $inputPassword) = split(/ /, $text, 2);
    if (!$inputPassword) {
        $inputPassword = $inputNick;
        $inputNick = $nick;
    }

    if ($bot->is_term_user($inputNick) || $sessions{$inputNick}) {
        return $bot->say($nick, "You are already identified.");
    }

    if (!$inputPassword) {
        return $bot->notice($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick id [nick] <password>");
    }

    if (!$db->{$inputNick}) {
        return $bot->notice($nick, "An account doesn't exist for $inputNick, did you register?");
    }

    my $db = ${$dbi->read("accounts.db")};
    my $hash = hashpw("$inputNick:".$db->{$inputNick}->{ctime}, $text);

    if ($hash eq $db->{$inputNick}->{password}) {
        $db->{$nick}->{ltime} = time();
        $db->{$nick}->{lhost}  = $host;

        $sessions{$nick} = {
            host => $host,
            account => $inputNick
        };

        $bot->say($nick, "You are now identifed.");
        $bot->log("Accounts: $nick identified as $inputNick", "Accounts");
    } else {
        $dbi->free();
        return $bot->say($nick, "Invalid password.");
    }

    $dbi->write();
}

sub acc_passwd {
    my ($nick, $host, $text) = @_;
    
    my $db = ${$dbi->read("accounts.db")};
    if (!$sessions{$nick} || !exists($db->{$nick})) { 
        $dbi->free();
        return $bot->notice($nick, "You are not identified or don't have an account.");
    }

    my $ctime = $db->{$nick}->{ctime};
    $db->{$nick}->{password} = hashpw("$nick:$ctime", $text);
    $dbi->write();

    $bot->notice($nick, "Password updated.");
}

sub acc_quit_ev {
    my ($nick, $host) = @_;

    if ($sessions{$nick}) {
        delete $sessions{$nick};
    }
}

sub acc_admin_interface {
    my ($nick, $host, $text) = @_;

    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->say($nick, "Unauthorized");
    }

    my $fmt = Shadow::Formatter->new();

    # process commands
    my @tmp = split(/ /, $text);
    my $cmd = shift(@tmp);
    my $arg1 = shift(@tmp);
    my $arg2 = shift(@tmp);
    $text = join(" ", @tmp);

    if (!$cmd) {
        return $bot->say($nick, "Missing subcommand.  See \x02".$help->cmdprefix($nick)."help accounts\x02 for more information.");
    }

    my $db  = ${$dbi->read("accounts.db")};
    # accounts list
    # accounts remove <nick>
    # accounts whois <nick>
    # accounts passwd <nick> <pass>

    if ($cmd =~ /list/i) {
        $fmt->table_header("Nick", "Created", "Host");

        foreach my $k (keys(%{$db})) {
            $fmt->table_row(
                $k,
                "".gmtime($db->{$k}->{ctime})." GMT",
                $db->{$k}->{lhost}
            );
        }

        $bot->fastsay($nick, $fmt->table());
    } elsif ($cmd =~ /remove/i) {
        if (exists($db->{$arg1})) {
            delete $db->{$arg1};
            $bot->say($nick, "Removed account $arg1");
            $bot->log($nick, "Accounts: Removed account $arg1 [Issued by $nick]", "Accounts");
        } else {
            $dbi->free();
            return $bot->say($nick, "No account exists for $arg1");
        }
    } elsif ($cmd =~ /whois/i) {
        if (exists($db->{$arg1})) {
            $fmt->table_header("Property", "Value");

            foreach my $k (keys(%{$db->{$arg1}})) {
                my ($rkey, $rval) = ($k, $db->{$arg1}->{$k});
                
                if ($rkey eq "ltime") { $rkey = "last login time"; $rval = "".gmtime($rval)." GMT"; }
                if ($rkey eq "lhost") { $rkey = "last login host"; }
                if ($rkey eq "admin") { $rval = $rval == 1 ? "yes" : "no"; }
                if ($rkey eq "ctime") { $rkey = "created"; $rval = "".gmtime($rval)." GMT"; }
                
                $fmt->table_row($rkey, $rval);
            }
            
            $fmt->table_row("login status", exists($sessions{$arg1}) ? "\x033Online\x03" : "\x034Offline\x03");

            $bot->fastsay($nick, $fmt->table());
        } else {
            $dbi->free();
            return $bot->say($nick, "No account exists for $arg1");
        }
    } elsif ($cmd =~ /passwd/i) {
        if (exists($db->{$arg1})) {
            my $ctime = $db->{$arg1}->{ctime};
            $db->{$arg1}->{password} = hashpw("$nick:$ctime", $arg2);
        } else {
            $dbi->free();
            return $bot->say($nick, "No account exists for $arg1");
        }
    } else {
        $dbi->free();
        return $bot->say($nick, "Invalid subcommand.  See \x02".$help->cmdprefix($nick)."help accounts\x02 for more information.");
    }

    $dbi->write();
}

sub unloader {
    $bot->unregister("Accounts");

    $bot->del_handler("privcmd register", "acc_register");
    $bot->del_handler("privcmd id", "acc_id");
    $bot->del_handler("privcmd passwd", "acc_passwd");
    $bot->del_handler("event quit", "acc_quit_ev");
    $bot->del_handler("privcmd accounts", "acc_admin_interface");

    $help->del_help("accounts", "Admin");
    $help->del_help("register", "General");
    $help->del_help("id", "General");
    $help->del_help("passwd", "General");

    $bot->del_handler('module load', 'acc_webmod_init');
    $bot->del_handler('module reload', 'acc_webmod_init');
    $bot->del_handler('module unload', 'acc_webmod_cleanup');

    acc_webmod_cleanup("WebAdmin");

    $bot->store("accounts.sessions", \%sessions);
    $dbi->free();
}

1;
