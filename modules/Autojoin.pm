package Autojoin;

# Shadow Module: Autojoin
# Module that implements an autojoin feature, which is a list of channels
# to automatically join on connect that is manipulated via IRC commands.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use JSON;

my $bot  = Shadow::Core;
my $help = Shadow::Help;

my $dbfile = "./etc/autojoin.db";

sub loader {
  $bot->add_handler('event connected', 'Autojoin_connected');
  $bot->add_handler('privcmd autojoin', 'autojoin');

  $help->add_help('autojoin', 'Admin', '<add|del|list> <chan> [key]', 'Shadow Autojoin Module');

  if (!-e $dbfile) {
    open(my $fh, ">", $dbfile) or $bot->err("Autojoin Error creating db: ".$!, 0);
    print $fh "{}";
    close($fh);
  }
}

sub Autojoin_readdb {
  my $data;

  open(my $db, "<", $dbfile) or return $bot->err("Autojoin Error opening $dbfile: $!", 0);
  @data = <$db>;
  close($db);

  my $t = join("", @data);
  my $r = from_json($t, { utf8 => 1 });
  return $r;
}

sub Autojoin_writedb {
  my ($data) = @_;

  $json_text   = to_json( $data, { ascii => 1, pretty => 0} );

  open(my $db, ">", $dbfile) or return $bot->err("Autojoin Error opening $dbfile: $!", 0);
  print $db $json_text;
  close($db);
}

sub Autojoin_connected {
    my $db = Autojoin_readdb();

    foreach my $chan (keys $db) {
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

      foreach my $chan (keys $db) {
        $clist .= $chan.", ";
      }

      $bot->notice($nick, "\x02*** AUTOJOIN LIST ***\x02");
      $bot->notice($nick, $clist);
    }
  }
}

sub unloader {
  $bot->del_handler('event connected', 'Autojoin_connected');
  $bot->del_handler('privcmd autojoin', 'autojoin');

  $help->del_help('autojoin', 'Admin');
}

1;
