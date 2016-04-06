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

package RSS;

use warnings;
use JSON;
use Time::Seconds;
use Mojo::IOLoop;
use Mojo::UserAgent;
use XML::Feed;
use Data::Dumper;

my $bot      = Shadow::Core;
my $help     = Shadow::Help;
my $feedfile = "./etc/feeds.db";
my $ua       = Mojo::UserAgent->new;
my %feedcache;

sub loader {
  $bot->add_handler('event connected', 'rss_connected');
  $bot->add_handler('privcmd rss', 'rss_irc_interface');

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
  my ($command, $arg1, $arg2, $arg3) = split(" ", $text);
  my $db;

  if ($command eq "add" || $command eq "ADD") {
    if (!$arg1 || !$arg2 || !$arg3) {
      return $bot->notice($nick, "Syntax: /msg ".$Shadow::Core::nick." rss add <chan> <title> <url>");
    }

    if ($bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1)) {
      $db = rss_dbread();
      $db->{$arg1}->{$arg2} = {
        url => $arg3,
        lastSync => 0,
        syncInterval => 300,
        read => []
      };

      rss_dbwrite($db);
      $bot->notice($nick, "Added feed $arg2 [$arg3] for $arg1.");
      $bot->log("RSS: New feed for $arg1 [$arg2 - $arg3] added by $nick.");
      $bot->notice($nick, "Feed post should start appearing in $arg1 within 5 minutes.");
    }
  }
  elsif ($command eq "del" || $command eq "DEL") {

  }
  elsif ($command eq "list" || $command eq "LIST") {

  }
  elsif ($command eq "set" || $command eq "SET") {

  }
  elsif ($command eq "sync" || $command eq "SYNC") {

  } else {
    $bot->notice($nick, "Invalid command.  For help: /msg $Shadow::Core help rss");
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

  foreach my $chan (keys $db) {
    foreach my $title (keys $db->{$chan}) {
      my $synctime = $db->{$chan}->{$title}->{lastSync} + $db->{$chan}->{$title}->{syncInterval};

      if (time() >= $synctime) {
        $bot->log("RSS: Refreshing feed $title for $chan");
        $db->{$chan}->{$title}->{lastSync} = time();
        rss_dbwrite($db);

        if (!$feedcache{$db->{$chan}->{$title}->{url}}) {
          $ua->get($db->{$chan}->{$title}->{url} => json => {a => 'b'} => sub {
            my ($ua, $tx) = @_;

            if (my $err = $tx->error) {
              return $bot->err("RSS: Error fetching RSS feed $title for $chan: ".$err->{message}, 0);
            }

            my $body = \scalar($tx->res->body);
            my $parsedfeed;


            $feedcache{$db->{$chan}->{$title}->{url}} = $body;
            rss_agrigator($body, $title, $chan);
          });
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
  $bot->del_handler('event connected', 'rss_connected');
  $bot->del_handler('event tick', 'rss_tick');
  $bot->del_handler('privcmd rss', 'rss_irc_interface');
}

1;
