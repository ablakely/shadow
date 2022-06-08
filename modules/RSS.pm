# RSS - Shadow RSS Module
# v1.0
# Written by Aaron Blakely <aaron@ephasic.org>
#
# feed.db format:
# [
#   "#chan": {
#     "title": {
#       url: "",
#       lastSync: epoch,
#       syncInterval: seconds,
#       read: [{
#         url: "",
#         lastRecieved: epoch
#       }]
#     }
#   }
# ]
#
# TODO:
#  set command: interval, format, etc
#  HTTP connection keep alive support
#  Better db format?
#  .last channel command for last 5 feeds
#  Make not a memory hog.



package RSS;

use warnings;
use JSON;
use Time::Seconds;
use Mojo::IOLoop;
use Mojo::UserAgent;
use XML::Feed;

my $bot      = Shadow::Core;
my $help     = Shadow::Help;
my $feedfile = "./etc/feeds.db";
my $ua       = Mojo::UserAgent->new;
my %feedcache;

sub loader {
  $bot->log("[RSS] Loading: RSS module v1.0");
  $bot->add_handler('event connected', 'rss_connected');
  $bot->add_handler('privcmd rss', 'rss_irc_interface');
  $help->add_help("rss", "Channel", "<add|del|list|set|sync> [#chan] [feed name] [url]", "RSS module interface.", 0, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02RSS\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02rss\x02 is a command used for managing RSS feeds for each channel.");
    $bot->say($nick, "This command uses subcommands to perform different actions:");
    $bot->say($nick, "  \x02add\x02 #chan <feed name> <url> - Adds a feed for a channel.");
    $bot->say($nick, "  \x02del\x02 #chan <feed name> - Removes a feed from a channel.");
    $bot->say($nick, "  \x02set\x02 #chan <feed name> <setting> <value> - Not yet implemented.");
    $bot->say($nick, "  \x02list\x02 #chan - Lists all of the feeds for a given channel.");
    $bot->say($nick, "  \x02sync\x02 - Forces the bot to sync all feeds.");
    $bot->say($nick, " ");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick rss <add|del|list|set|sync> [#chan] [feed name] [url]");
  });

  if (!-e $feedfile) {
    $bot->log("RSS: No feed database found, creating one.");
    open(my $db, ">", $feedfile) or $bot->error("RSS: Error: Couldn't open $feedfile: $!");
    print $db "{}";
    close($db);
  }
}

sub rss_connected {
  $bot->add_handler('event tick', 'rss_tick');
}

sub rss_dbread {
  my @dbread;
  my $jsonstr;

  open(my $db, "<", $feedfile) or $bot->err("RSS: Error: Couldn't open $feedfile: $!");
  while (my $line = <$db>) {
    chomp $line;
    $jsonstr .= $line;
  }
  close($db);

  return from_json($jsonstr, { utf8 => 1 });
}

sub rss_dbwrite {
  my ($data) = @_;
  my $jsonstr = to_json($data, { utf8 => 1, pretty => 1 });

  open(my $db, ">", $feedfile) or $bot->err("RSS: Error: Couldn't open $feedfile: $!");
  print $db $jsonstr;
  close($db);
}

sub rss_irc_interface {
  my ($nick, $host, $text) = @_;
  my ($command, $arg1, $arg2, $arg3, $arg4) = split(" ", $text);
  my $db;

  if ($command eq "add" || $command eq "ADD") {
    if (!$arg1 || !$arg2 || !$arg3) {
      return $bot->notice($nick, "Syntax: /msg ".$Shadow::Core::nick." rss add <chan> <title> <url>");
    }

    if ($bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1)) {
      $db = rss_dbread();
      $db->{lc($arg1)}->{$arg2} = {
        url => $arg3,
        lastSync => 0,
        syncInterval => 300,
        read => []
      };

      rss_dbwrite($db);
      $bot->notice($nick, "Added feed $arg2 [$arg3] for $arg1.");
      $bot->log("RSS: New feed for $arg1 [$arg2 - $arg3] added by $nick.");
      $bot->notice($nick, "Feed post should start appearing in $arg1 within 5 minutes.");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: ADD $arg1 $arg2 :$arg3");
    }
  }
  elsif ($command eq "del" || $command eq "DEL") {
    if (!$arg1 || !$arg2) {
      return $bot->notice($nick, "Syntax: /msg ".$Shadow::Core::nick." rss del <chan> <title>");
    }

    if ($bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1)) {
      $db = rss_dbread();
      my $url = $db->{lc($arg1)}->{$arg2}->{url};
            
      delete($db->{lc($arg1)}->{$arg2});            
      rss_dbwrite($db);

      $bot->notice($nick, "Deleted feed $arg2 [$url] for $arg1.");
      $bot->log("RSS: Feed $arg2 [$url] was removed from $arg1 by $nick.");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: DEL $arg1 $arg2 :$arg3");
    }

  }
  elsif ($command eq "list" || $command eq "LIST") {
    if (!$arg1) {
      return $bot->notice($nick, "Syntax: /msg ".$Shadow::Core::nick." rss list <chan>");
    }

    $arg1 = lc($arg1);

    if ($bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1)) {
      $db = rss_dbread();
      my $feeds = "";

      foreach my $feed (keys %{$db->{$arg1}}) {
        $feeds .= $feed.", ";
      }

      $bot->notice($nick, "*** $arg1 RSS FEEDS ***");
      $bot->notice($nick, $feeds);
      $bot->log("RSS: LIST command issued by $nick for $arg1");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: LIST $arg1");
    }
  }
  elsif ($command eq "set" || $command eq "SET") {
    if (!$arg1 || !$arg2 || !$arg3) {
      return $bot->notice($nick, "Syntax: /msg $Shadow::Core::nick RSS SET <option> <chan> <feed> <value>");
    }

    if ($arg1 eq "SYNCTIME" || $arg1 eq "synctime") {
      if ($bot->isin($arg2, $Shadow::Core::nick) && $bot->isop($nick, $arg2)) {
        $db = rss_dbread();
        $arg2 = lc($arg2);
        $db->{$arg2}->{$arg3}->{syncInterval} = $arg4;
        rss_dbwrite($db);

        $bot->notice($nick, "Updated sync interval to $arg4 for feed $arg3 in $arg2.");
        $bot->log("RSS: SET SYNCTIME was used by $nick for $arg3 in $arg2.");
      }
    } else {
      $bot->notice($nick, "SET options: SYNCTIME");
    }
  }
  elsif ($command eq "sync" || $command eq "SYNC") {
    if ($bot->isbotadmin($nick, $host)) {
      $bot->notice($nick, "Refreshing RSS feeds.");
      rss_refresh();
      $bot->log("RSS: Forced to refresh feeds by botadmin $nick");
    } else {
      $bot->notice($nick, "Access denied.");
      $bot->log("RSS: Command denied for $nick: SYNC");
    }
  } else {
    $bot->notice($nick, "Invalid command.  For help: /msg $Shadow::Core::nick help rss");
  }
}

sub rss_checkread {
  my ($chan, $title, $link) = @_;
  my $db = rss_dbread();

  foreach my $post (@{$db->{$chan}->{$title}->{read}}) {
    foreach my $r ($post) {
      if ($r->{url} eq $link) {
        return 1;
      }
    }
  }
}

sub rss_updateread {
  my ($chan, $title, $link) = @_;
  my $db = rss_dbread();

  for (my $i = 0; $i < scalar(@{$db->{$chan}->{$title}->{read}}); $i++) {
    if ($db->{$chan}->{$title}->{read}->[$i]->{url} eq $link) {
      $db->{$chan}->{$title}->{read}->[$i]->{lastRecieved} = time();
    }
  }

  rss_dbwrite($db);
}

sub rss_agrigator {
  my ($rawxml, $title, $chan) = @_;
  my $db = rss_dbread();

  my $parsedfeed = XML::Feed->parse($rawxml) or return $bot->err("RSS: Parser error on feed $title: ".XML::Feed->errstr, 0);
  for my $entry ($parsedfeed->entries) {
    my $read = rss_checkread($chan, $title, $entry->link());

    if (!$read) {
      $bot->say($chan, "$title: ".$entry->title()." [".$entry->link()."]", 3);

      push(@{$db->{$chan}->{$title}->{read}}, {
        url => $entry->link(),
        lastRecieved => time()
      });
    } else {
      rss_updateread($chan, $title, $entry->link());
    }
  }

  rss_dbwrite($db);
}

sub rss_refresh {
  my $db = rss_dbread();

  foreach my $chan (keys %{$db}) {
    foreach my $title (keys %{$db->{$chan}}) {
      my $synctime = $db->{$chan}->{$title}->{lastSync} + $db->{$chan}->{$title}->{syncInterval};

      if (time() >= $synctime) {
        $bot->log("RSS: Refreshing feed $title for $chan");
        $db->{$chan}->{$title}->{lastSync} = time();
        rss_dbwrite($db);

        if (!$feedcache{$db->{$chan}->{$title}->{url}}) {
          #$ua->get($db->{$chan}->{$title}->{url} => json => {a => 'b'} => sub {
          #  my ($ua, $tx) = @_;

          #  if (my $err = $tx->error) {
          #    return $bot->err("RSS: Error fetching RSS feed $title for $chan: ".$err->{message}, 0);
          #  }

          #  my $body = \scalar($tx->res->body);
          #  my $parsedfeed;


          #  $feedcache{$db->{$chan}->{$title}->{url}} = $body;
          #  rss_agrigator($body, $title, $chan);
          #});

          my $rss_feed = $ua->get_p($db->{$chan}->{$title}->{url});

          Mojo::Promise->all($rss_feed)->then(sub($rss) {
            if (my $err = $rss->error) {
              return $bot->err("RSS: Error fetching RSS feed $title for $chan: ".$err->{message}, 0);
            }

            my $body = \scalar($rss->[0]->result->body);
            my $parsedfeed;

            $feedcache->{$db->{$chan}->{$title}->{url}} = $body;
            rss_agrigator($body, $title, $chan);
          })->wait;

        } else {
          rss_agrigator($feedcache{$db->{$chan}->{$title}->{url}}, $title, $chan);
        }
      }
    }
  }
  %feedcache = ();
}

sub rss_tick {
  Mojo::IOLoop->one_tick();
  rss_refresh();
}

sub unloader {
  $bot->log("[RSS] Unloading RSS module");
  $bot->del_handler('event connected', 'rss_connected');
  $bot->del_handler('event tick', 'rss_tick');
  $bot->del_handler('privcmd rss', 'rss_irc_interface');

  $help->del_help("rss", "Channel");
}

1;
