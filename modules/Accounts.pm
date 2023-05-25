package Accounts;
# Accounts - User accounts module
#
# Written by Aaron Blakely <aaron@ephasic.org>

use Digest::SHA qw(sha256_hex);

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;

my $dbi  = Shadow::DB->new();
my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
    $bot->register("Accounts", "v0.1", "Aaron Blakely", "User Accounts");

    $bot->add_handler("privcmd register", "acc_register");
    $bot->add_handler("privcmd id", "acc_id");
    
    my $db = ${$dbi->read("accounts.db")};
    if (!scalar(keys(%{$db}))) {
        $dbi->write();
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

    if ($bot->isbotadmin($nick, $host)) {
        $db->{$nick}->{admin} = 1;
    }

    $bot->notice($nick, "Account created for $nick");
    $dbi->write();
}

sub acc_id {
    my ($nick, $host, $text) = @_;
    my $db = ${$dbi->read("accounts.db")};

    if ($bot->is_term_user($nick)) {
        return $bot->say($nick, "You are already identified.");
    }

    if (!$text) {
        return $bot->notice($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick id <password>");
    }

    if (!$db->{$nick}) {
        return $bot->notice($nick, "An account doesn't exist for $nick, did you register?");
    }

    my $salt = sha256_hex($nick.":".$db->{$nick}->{ctime});
    my $hash = sha256_hex($salt.$text.$salt);

    if ($hash eq $db->{$nick}->{password}) {
        $db->{$nick}->{ltime} = time();
        $db->{$nick}->{lhost}  = $host;

        $bot->say($nick, "You are now identifed.");
        $bot->log("Accounts: $nick identified", "Accounts");
    } else {
        return $bot->say($nick, "Invalid password.");
    }

    $dbi->write();
}

sub unloader {
    $bot->unregister("Accounts");

    $bot->del_handler("privcmd register", "acc_register");
    $bot->del_handler("privcmd id", "acc_id");
}

1;
