package Autojoin;

# Shadow Module: Autojoin
# Module that implements an autojoin feature, which is a list of channels
# to automatically join on connect that is manipulated via IRC commands.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use JSON;
use Shadow::Core;
use Shadow::Help;

my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();

my $dbfile = "./etc/autojoin.db";

sub loader {
  $bot->register("Autojoin", "v1.0", "Aaron Blakely", "Autojoin channels");
  $bot->add_handler('event connected', 'Autojoin_connected');
  $bot->add_handler('privcmd autojoin', 'autojoin');

  $help->add_help('autojoin', 'Admin', '<add|del|list> <chan> [key]', 'Shadow Autojoin Module', 0, sub {
    my ($nick, $host, $text) = @_;

    my $cmdprefix = "/msg $Shadow::Core::nick ";
    $cmdprefix = "/" if ($bot->is_term_user($nick));
    
    $bot->say($nick, "Help for \x02AUTOJOIN\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02autojoin\x02 is a command for managing which channels the bot automatically joins on connect.");
    $bot->say($nick, "This command uses a set of subcommands to perform actions:");
    $bot->say($nick, "  \x02add\x02 - Adds a channel to the autojoin list.");
    $bot->say($nick, "  \x02del\x02 - Removes a channel from the autojoin list.");
    $bot->say($nick, "  \x02list\x02 - Lists all the channels the bot automatically joins.");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02SYNTAX\x02: ${cmdprefix}autojoin <add|del|list> [chan] [key]");
  });

  if (!-e $dbfile) {
    open(my $fh, ">", $dbfile) or $bot->err("Autojoin Error creating db: ".$!, 0, "Modules");
    print $fh "{}";
    close($fh);
  }
}

sub Autojoin_readdb {
  my $data;

  open(my $db, "<", $dbfile) or return $bot->err("Autojoin Error opening $dbfile: $!", 0, "Modules");
  @data = <$db>;
  close($db);

  my $t = join("", @data);
  my $r = from_json($t, { utf8 => 1 });
  return $r;
}

sub Autojoin_writedb {
  my ($data) = @_;

  $json_text   = to_json( $data, { ascii => 1, pretty => 0} );

  open(my $db, ">", $dbfile) or return $bot->err("Autojoin Error opening $dbfile: $!", 0, "Modules");
  print $db $json_text;
  close($db);
}

sub Autojoin_connected {
    my $db = Autojoin_readdb();

    foreach my $chan (keys %{$db}) {
      $bot->join($chan);
    }
}

sub autojoin {
  my ($nick, $host, $text) = @_;
  my ($cmd, $chan, $key) = split(" ", $text);

  if ($bot->isbotadmin($nick, $host)) {
    my $db = Autojoin_readdb();

    if (!$cmd) {
      return $bot->notice($nick, "Syntax: autojoin <add|del|list> <channel> [key]");
    }

    if ($cmd eq "add") {
      $db->{$chan} = $key;
      Autojoin_writedb($db);

      $bot->join($chan);
      $bot->notice($nick, "Added $chan to auto join list.");
    } elsif ($cmd eq "del") {
      delete $db->{$chan};
      Autojoin_writedb($db);

      $bot->part($chan, "Removed from autojoin.");
      $bot->notice($nick, "Removed $chan from auto join list.")
    } elsif ($cmd eq "list") {
      my $clist = "";

      foreach my $chan (keys %{$db}) {
        $clist .= $chan.", ";
      }

      $bot->notice($nick, "\x02*** AUTOJOIN LIST ***\x02");
      $bot->notice($nick, $clist);
    }
  }
}

sub unloader {
  $bot->unregister("Autojoin");
  $bot->del_handler('event connected', 'Autojoin_connected');
  $bot->del_handler('privcmd autojoin', 'autojoin');

  $help->del_help('autojoin', 'Admin');
}

1;
