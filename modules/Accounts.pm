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
        return 1;
    }

    return 0;
}

sub get_account_prop {
    my ($self, $nick, $prop) = @_;

    my $db = ${$dbi->read("accounts.db")};

    if (exists($db->{$nick}->{$prop})) {
        return $db->{$nick}->{$prop};
    }

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
sub loader {
    $bot->register("Accounts", "v0.1", "Aaron Blakely", "User Accounts");

    $bot->add_handler("privcmd register", "acc_register");
    $bot->add_handler("privcmd id", "acc_id");
    $bot->add_handler("event quit", "acc_quit_ev");
    $bot->add_handler("privcmd accounts", "acc_admin_interface");

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

    if ($bot->isloaded("WebAdmin")) {
        $web = WebAdmin->new();
        my $router = $web->router();  
        my $db     = ${$dbi->read("accounts.db")};
        
        foreach my $k (keys(%{$db})) {
            $db->{$k}->{ctime} = "".gmtime($db->{$k}->{ctime})." GMT";
        }

        my @dbk    = keys(%{$db});

        $web->add_navbar_link("/accounts", "users", "Accounts");
        $router->get('/accounts', sub {
            my ($client, $params, $headers, $buf) = @_;

            if ($web->checkSession($headers)) {
                $router->headers($client);

                $web->out($client, $web->render("mod-accounts.ejs", {
                    nav_active => "Accounts",
                    db => $db,
                    dbkeys => \@dbk
                }));
            } else {
                $router->redirect($client, "/");
            }
        });
    }
}

sub acc_register {
    my ($nick, $host, $text) = @_;
    my $db = ${$dbi->read("accounts.db")};
    
    if ($bot->is_term_user($nick)) {
        return $bot->say($nick, "Account registration is only available over IRC.");
    }

    if (!$text) {
        return $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick register <password>");
    }

    if ($db->{$nick}) {
        return $bot->say($nick, "Account already exists for $nick.");
    }

    my $ctime = time();
    my $salt  = sha256_hex("$nick:$ctime");

    $db->{$nick} = {};
    $db->{$nick}->{ctime}    = time();
    $db->{$nick}->{password} = sha256_hex($salt.$text.$salt);
    $db->{$nick}->{admin} = $bot->isbotadmin($nick, $host) ? 1 : 0;

    $bot->notice($nick, "Account created for $nick");
    $dbi->write();
}

sub acc_id {
    my ($nick, $host, $text) = @_;
    my $db = ${$dbi->read("accounts.db")};

    my ($inputNick, $inputPassword) = split(/ /, $text, 2);
    $inputPassword = $inputNick if (!$inputPassword);

    if ($bot->is_term_user($nick) || $sessions{$nick}) {
        return $bot->say($nick, "You are already identified.");
    }

    if (!$inputPassword) {
        return $bot->notice($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick id [nick] <password>");
    }

    if (!$db->{$nick}) {
        return $bot->notice($nick, "An account doesn't exist for $nick, did you register?");
    }

    my $salt = sha256_hex($nick.":".$db->{$nick}->{ctime});
    my $hash = sha256_hex($salt.$text.$salt);

    if ($hash eq $db->{$nick}->{password}) {
        $db->{$nick}->{ltime} = time();
        $db->{$nick}->{lhost}  = $host;

        $sessions{$nick} = {};
        $sessions{$nick}->{host} = $host;

        $bot->say($nick, "You are now identifed.");
        $bot->log("Accounts: $nick identified", "Accounts");
    } else {
        return $bot->say($nick, "Invalid password.");
    }

    $dbi->write();
}

sub acc_quit_ev {
    my ($nick, $host) = @_;

    my $db = ${$dbi->read()};
    if ($sessions{$nick}) {
        delete $sessions{$nick};
    }
}

sub acc_admin_interface {
    my ($nick, $host, $text) = @_;

    if (!$bot->isbotadmin($nick, $host)) {
        return $bot->say($nick, "Unauthorized");
    }

    my $db  = ${$dbi->read("accounts.db")};
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

    # accounts list
    # accounts remove <nick>
    # accounts whois <nick>
    # accounts passwd <nick> <pass>
    # accounts session <nick>

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
            return $bot->say($nick, "No account exists for $arg1");
        }
    } elsif ($cmd =~ /passwd/i) {

    } else {
        return $bot->say($nick, "Invalid subcommand.  See \x02".$help->cmdprefix($nick)."help accounts\x02 for more information.");
    }

    $dbi->write();
}

sub unloader {
    $bot->unregister("Accounts");

    $bot->del_handler("privcmd register", "acc_register");
    $bot->del_handler("privcmd id", "acc_id");
    $bot->del_handler("event quit", "acc_quit_ev");
    $bot->del_handler("privcmd accounts", "acc_admin_interface");

    $help->del_help("accounts", "Admin");

    if ($bot->isloaded("WebAdmin")) {
        my $router = $web->router();

        $web->del_navbar_link("Accounts");
        $router->del('get', '/accounts');
    }
}

1;
