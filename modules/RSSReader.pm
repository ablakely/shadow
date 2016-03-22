# RSSReader - Shadow RSS Reader Module
# v0.5
# Written by Aaron Blakely <aaron@ephasic.org>
#
# COMMANDS:
#   channel - rsssync - Sync all active RSS feeds.
#   private - addfeed - Adds a feed.
#   private - delfeed - Removes a feed.
#   private - listfeeds - Lists all active feeds.
#
# DEPENDENCIES:
#   This module requires Mojo::UserAgent and Mojo::IOLoop to
#   be installed on the system.
#
# SYNCTIME:
#   Default sync interval is 5 min (300 sec)
#
# TODO:
# Reimplement using new 'tick' event and don't ignore cache maxAge headers.

package RSSReader;

my $bot   = Shadow::Core;
my $help  = Shadow::Help;

use warnings;
use JSON;
use Mojo::UserAgent;
use Mojo::IOLoop;
use XML::Feed;

our $SYNCTIME = 300;  # How offten do we check RSS feeds? (in seconds)
my $feeds = "./etc/feeds.db";
my $ua    = Mojo::UserAgent->new;

sub loader {
  $bot->add_handler('event tick', 'RSSReader_iotick');
  $bot->add_handler('privcmd addfeed', 'RSSReader_addfeed');
  $bot->add_handler('privcmd delfeed', 'RSSReader_delfeed');
  $bot->add_handler('chancmd rsssync', 'RSSReader_rsssync');
  $bot->add_handler('privcmd listfeeds', 'RSSReader_listfeed');
  $bot->add_handler('privcmd rssdbcleanup', 'RSSReader_dbcleanup');

  $help->add_help('addfeed', 'RSSReader', '<chan> <title> <url>', 'Enables the RSS Reader module.');
  $help->add_help('delfeed', 'RSSReader', '<chan> <title>', 'Deletes a RSS feed.');
  $help->add_help('listfeeds', 'RSSReader', '<chan>', 'Lists all active RSS feeds for a channel.');
  $help->add_help('rsssync', 'Channel', '', 'Syncs all RSS feeds. [F]');

  $bot->add_timeout($SYNCTIME, 'RSSReader_feedagrigator');

  if (!-e $feeds) {
    open(my $fh, ">", $feeds) or print "RSSReader Error: ".$!;
    print $fh "{}";
    close($fh);
  }
}

sub RSSReader_iotick {
  Mojo::IOLoop->one_tick();
}

sub RSSReader_writedb {
  my ($data) = @_;

  $json_text   = to_json( $data, { ascii => 1, pretty => 0} );

  open(my $db, ">", $feeds) or print "RSSReader Error: ".$!;
  print $db $json_text;
  close($db);
}

sub RSSReader_readdb {
  my $data;

  open(my $db, "<", $feeds) or print "RSSReader Error: ".$!;
  @data = <$db>;
  close($db);

  my $t = join("", @data);
  my $r = from_json($t, { utf8 => 1 });
  return $r;
}

sub RSSReader_checkread {
  my ($chan, $title, $link) = @_;

  my $db = RSSReader_readdb();

  foreach my $chan (keys $db) {
    foreach my $title (keys $db->{$chan}) {
      foreach my $read (@{$db->{$chan}->{$title}->{readposts}}) {
        foreach my $r ($read) {
          if ($r eq $link) {
		          return 1;
	        }
        }
      }
    }
  }

  return 0;
}


sub RSSReader_listfeed {
  my ($nick, $host, $text) = @_;
  my $db                   = RSSReader_readdb();

  $bot->notice($nick, "\x02*** RSS Feeds ***\x02");

  foreach my $chan (keys $db) {
    foreach my $title (keys $db->{$chan}) {
      $bot->notice($nick, "[$chan] ".$title." - ".$db->{$chan}->{$title}->{url});
    }
  }
}


sub RSSReader_genfeed {
  my ($feed, $chan, $title) = @_;
  my %feedcache;
  my $f;

  my $db   = RSSReader_readdb();
  my @cp   = $db->{$chan}->{$title}->{readposts};

  $ua->get("$feed" => json => {a => 'b'} => sub {
    my ($ua, $tx) = @_;

    if (my $err = $tx->error) {
      return $bot->err("RSSReader Error on fetching feed: [$title]: ".$err->{message}, 0);
    }

    my $body = \scalar($tx->res->body);

    if (!$feedcache{$feed}) {
      $f = $feedcache{$feed} = XML::Feed->parse($body) or return $bot->err("RSS parser error on feed [$title]: ".XML::Feed->errstr, 0);
    } else {
      $f = $feedcache{$feed};
    }

    for my $entry ($f->entries) {
      my $x = RSSReader_checkread($chan, $title, $entry->link());
      if (!$x) {
        $bot->say($chan, "$title: ".$entry->title()." [".$entry->link()."]", 3);
        my $id = $entry->link();
        push(@{$db->{$chan}->{$title}->{readposts}}, $id);
      }
    }

    RSSReader_writedb($db);
  });
}


sub RSSReader_feedagrigator {

  my $db = RSSReader_readdb();
  my @feed;

  foreach my $chan (keys $db) {
    foreach my $title (keys $db->{$chan}) {
      RSSReader_genfeed($db->{$chan}->{$title}->{url}, $chan, $title);
    }
  }

  $bot->add_timeout($SYNCTIME, 'RSSReader_feedagrigator');
}

sub RSSReader_dbcleanup {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->notice($nick, "Preforming RSS Feed database cleanup.");
    $bot->log("RSSReader: Preforming RSS Feed database cleanup.");

    my $db = RSSReader_readdb();

    foreach my $chan (keys $db) {
      foreach my $title (keys $db->{$chan}) {
        $db->{$chan}->{$title}->{readposts} = ();
      }
    }

    RSSReader_writedb($db);
  }
}

sub RSSReader_addfeed {
  my ($nick, $host, $text) = @_;
  my ($chan, $title, $url) = split(/ /, $text);
  my $db;

  if (!$chan || !$title || !$url) {
    $bot->notice($nick, "Syntax: /msg $Shadow::Core::nick addfeed <chan> <title> <url>");
  } else {
    if ($bot->isin($chan, $Shadow::Core::nick) && $bot->isop($nick, $chan)) {
      $db = RSSReader_readdb();
      $db->{$chan}->{$title} = {
    	   url => $url,
	       readposts => []
       };

       RSSReader_writedb($db);
       $bot->notice($nick, "Enabled $title [$url] for $chan");
       $bot->log("$nick added new RSS feed: $title - $url - $chan");
       $bot->notice($nick, "Feed posts should start surfacing in channel within 5 minutes.");
     }
  }
}

sub RSSReader_delfeed {
  my ($nick, $host, $text) = @_;
  my ($chan, $title) = split(/ /, $text);

  if (!$chan || !$title) {
    $bot->notice($nick, "Syntax: /msg $Shadow::Core::nick delfeed <chan> <title>")
  } else {
    if ($bot->isin($chan, $Shadow::Core::nick) && $bot->isop($nick, $chan)) {
      my $db = RSSReader_readdb();

      delete $db->{$chan}->{$title};
      RSSReader_writedb($db);

      $bot->log("$nick removes RSS feed: $title - $url - $chan");
      $bot->notice($nick, "Disabling '$title' feed for $chan.");
    }
  }
}

sub RSSReader_rsssync {
  my ($nick, $host, $chan, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    $bot->say($chan, "$nick: Syncing RSS Feeds.");
    $bot->log("$nick preformed forced RSS sync in $chan");
    RSSReader_feedagrigator();
  }
}

sub unloader {
  $bot->del_handler('event tick', 'RSSReader_iotick');
  $bot->del_handler('privcmd addfeed', 'RSSReader_addfeed');
  $bot->del_handler('privcmd delfeed', 'RSSReader_delfeed');
  $bot->del_handler('chancmd rsssync', 'RSSReader_rsssync');
  $bot->del_handler('privcmd listfeeds', 'RSSReader_listfeed');

  $ua->_cleanup();

  $bot->del_help('addfeed', 'RSSReader');
  $bot->del_help('delfeed', 'RSSReader');
  $bot->del_help('rsssync', 'Channel');
  $bot->del_help('listfeed', 'RSSReader');
}

1;
