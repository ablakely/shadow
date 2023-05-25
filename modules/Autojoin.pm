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
}

sub Autojoin_connected {
    my $db = ${$dbi->read()}; 

    foreach my $chan (keys %{$db->{Autojoin}}) {
      $bot->join($chan);
    }
}

sub autojoin {
  my ($nick, $host, $text) = @_;
  my ($cmd, $chan, $key) = split(" ", $text);

  if ($bot->isbotadmin($nick, $host)) {
    my $db = ${$dbi->read()};

    if (!$cmd) {
      return $bot->notice($nick, "Syntax: autojoin <add|del|list> <channel> [key]");
    }

    if ($cmd eq "add") {
      $db->{Autojoin}->{$chan} = $key;

      $bot->join($chan);
      $bot->notice($nick, "Added $chan to auto join list.");
    } elsif ($cmd eq "del") {
      return $bot->notice($nick, "$chan is not in autojoin list") if (!$db->{Autojoin}->{$chan});
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
}

1;
