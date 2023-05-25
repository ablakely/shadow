# RSS - Shadow RSS Module
# v1.1
# Written by Aaron Blakely <aaron@ephasic.org>
#
# Changelog:
# v1.1 - Performance and feed compatibility improvements, formatting support
#
# feed.db format:
# [
#   "#chan": {
#     "title": {
#       url: "",
#       "format": "%FEED%: %TITLE% [%URL%]",
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
#  help submenus
#  .last channel command for last 5 feeds

package RSS;

use warnings;
use lib '../lib';
use utf8;
use JSON;
use Time::Seconds;
use Mojo::IOLoop;
use Mojo::UserAgent;
use XML::Feed;
use utf8;
use Encode qw( encode_utf8 );

use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;


my $bot      = Shadow::Core->new();
my $help     = Shadow::Help->new();
my $feedfile = "./etc/feeds.db";
my $ua       = Mojo::UserAgent->new;
my %feedcache;

sub loader {
  $bot->register("RSS", "v1.1", "Aaron Blakely", "RSS aggregator");

  $bot->log("[RSS] Loading: RSS module v1.1", "Modules");
  $bot->add_handler('event connected', 'rss_connected');
  $bot->add_handler('privcmd rss', 'rss_irc_interface');
  $help->add_help("rss", "Channel", "<add|del|list|set|sync> [#chan] [feed name] [url]", "RSS module interface.", 0, sub {
    my ($nick, $host, $text) = @_;

    my $cmdprefix = "/msg $Shadow::Core::nick ";
    $cmdprefix    = "/" if ($bot->is_term_user($nick));

    if ($text =~ /rss set/i) {
        $bot->say($nick, "Help for \x02RSS SET\x02:");
        $bot->say($nick, " ");
        $bot->say($nick, "\x02SYNTAX\x02: ${cmdprefix}rss set <option> <chan> <feed name> <value>");

        $bot->say($nick, " ");
        $bot->say($nick, "  Options:");
        $bot->say($nick, "    SYNCTIME - Refresh rate for a feed in seconds.");
        $bot->say($nick, "    FORMAT   - Change the output format for a feed:");
        $bot->say($nick, "      Example: \%FEED\%: \%TITLE\% [\%URL\%]");
        $bot->say($nick, "      ");
        $bot->say($nick, "      \%FEED\%: Feed name");
        $bot->say($nick, "      \%TITLE\%: RSS entry title");
        $bot->say($nick, "      \%URL\%: RSS entry link");
        $bot->say($nick, "      \%C\%: mIRC color escape character (ctrl + k)");
        $bot->say($nick, "      \%B\%: mIRC bold character (ctrl + b)");
        return;
    }

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
    $bot->say($nick, "\x02SYNTAX\x02: ${cmdprefix}rss <add|del|list|set|sync> [#chan] [feed name] [url]");
  });

  if (!-e $feedfile) {
    $bot->log("RSS: No feed database found, creating one.", "Modules");
    open(my $db, ">", $feedfile) or $bot->error("RSS: Error: Couldn't open $feedfile: $!");
    print $db "{}";
    close($db);
  }

  $ua->transactor->name("'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36'");

  rss_connected() if ($bot->connected());
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
  my ($command, $arg1, $arg2, $arg3, @args) = split(" ", $text);
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
        format => '%FEED%: %TITLE% [%URL%]',
        read => []
      };

      rss_dbwrite($db);
      $bot->notice($nick, "Added feed $arg2 [$arg3] for $arg1.");
      $bot->log("RSS: New feed for $arg1 [$arg2 - $arg3] added by $nick.", "Modules");
      $bot->notice($nick, "Feed post should start appearing in $arg1 within 5 minutes.");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: ADD $arg1 $arg2 :$arg3", "Modules");
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
      $bot->log("RSS: Feed $arg2 [$url] was removed from $arg1 by $nick.", "Modules");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: DEL $arg1 $arg2 :$arg3", "Modules");
    }

  }
  elsif ($command eq "list" || $command eq "LIST") {
    if (!$arg1) {
      return $bot->notice($nick, "Syntax: /msg ".$Shadow::Core::nick." rss list <chan>");
    }

    $arg1 = lc($arg1);

    my $chanauth = $bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1);

    if (!$chanauth && $arg1 =~ /all/i) {
        if ($bot->isbotadmin($nick, $host)) {
            $chanauth = 1;
        } else {
            $bot->log("RSS: Commanded denied for $nick: LIST ALL", "Modules");
            return $bot->notice($nick, "\x02RSS LIST ALL\x02 requires botadmin privileges.");
        }
    }

    if ($chanauth) {
      $db = rss_dbread();
      my @out;
      my $fmt = Shadow::Formatter->new();

      if ($arg1 =~ /all/i) {
          foreach my $chan (keys %{$db}) {
              $fmt->table_reset();
              $fmt->table_header("Feed", "URL", "Inverval", "Format");

              foreach my $feed (keys %{$db->{$chan}}) {
                  next if (!$db->{$chan}->{$feed}->{url});

                  $fmt->table_row(
                      $feed,
                      $db->{$chan}->{$feed}->{url},
                      $db->{$chan}->{$feed}->{syncInterval}." seconds",
                      $db->{$chan}->{$feed}->{format}
                  )
              }


              next if ($fmt->table_row_count() == 0);

              push(@out, "\x02*** $chan RSS FEEDS ***\x02");
              foreach my $line ($fmt->table()) {
                  push(@out, $line);
              }

              push(@out, " ");
          }
      } else {
          push(@out, "\x02*** $arg1 RSS FEEDS ***\x02");

          $fmt->table_header("Feed", "URL", "Interval", "Format");

          foreach my $feed (keys %{$db->{$arg1}}) {
              $fmt->table_row(
                  $feed,
                  $db->{$arg1}->{$feed}->{url},
                  $db->{$arg1}->{$feed}->{syncInterval}." seconds",
                  $db->{$arg1}->{$feed}->{format}
              )
          }

          foreach my $line ($fmt->table()) {
              push(@out, $line);
          }
      }
      
      $bot->fastsay($nick, @out);

      $bot->log("RSS: LIST command issued by $nick for $arg1", "Modules");
    } else {
      $bot->notice($nick, "Command requres channel op (+o) mode.");
      $bot->log("RSS: Command denied for $nick: LIST $arg1", "Modules");
    }
  }
  elsif ($command eq "set" || $command eq "SET") {
    if ($arg1 eq "SYNCTIME" || $arg1 eq "synctime") {
      return $bot->notice($nick, "\002SYNTAX\002: /msg $Shadow::Core::nick rss set SYNCTIME <chan> <feed> <interval in seconds>") if (!$arg2 || !$arg3 || !$args[0]);
      if ($bot->isin($arg2, $Shadow::Core::nick) && $bot->isop($nick, $arg2)) {
        $db = rss_dbread();
        $arg2 = lc($arg2);
        $db->{$arg2}->{$arg3}->{syncInterval} = $args[0];
        rss_dbwrite($db);

        $bot->notice($nick, "Updated sync interval to $args[0] for feed $arg3 in $arg2.");
        $bot->log("RSS: SET SYNCTIME was used by $nick for $arg3 in $arg2.", "Modules");
      }
    } elsif ($arg1 eq "FORMAT" || $arg1 eq "format") {
      return $bot->notice($nick, "\002SYNTAX\002: /msg $Shadow::Core::nick rss set FORMAT <chan> <feed> <format string>") if (!$arg2 || !$arg3 || !$args[0]);

      if ($bot->isin($arg2, $Shadow::Core::nick) && $bot->isop($nick, $arg2)) {
        $db = rss_dbread();
        $arg2 = lc($arg2);
        $db->{$arg2}->{$arg3}->{format} = join(" ", @args);
        rss_dbwrite($db);

        $bot->notice($nick, "Updated format to \002".join(" ", @args)."\002 for feed $arg3 in $arg2.");
        $bot->log("RSS: SET FORMAT was used by $nick for $arg3 in $arg2.", "Modules");
      }
    } else {
      $bot->notice($nick, "SET options: SYNCTIME FORMAT");
    }
  }
  elsif ($command eq "sync" || $command eq "SYNC") {
    if ($bot->isbotadmin($nick, $host)) {
      $bot->notice($nick, "Refreshing RSS feeds.");
      rss_refresh();
      $bot->log("RSS: Forced to refresh feeds by botadmin $nick", "Modules");
    } else {
      $bot->notice($nick, "Access denied.");
      $bot->log("RSS: Command denied for $nick: SYNC", "Modules");
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
    my $fmtstring = $db->{$chan}->{$title}->{format};
    my $tmplink = $entry->link();
    my $read = rss_checkread($chan, $title, $tmplink);

    my $tmptitle;
    my @tokens;

    if (!$read) {
      push(@{$db->{$chan}->{$title}->{read}}, {
        url => $tmplink,
        lastRecieved => time()
      });
      
      if ($tmplink =~ /nitter\.net/) {
        $tmplink =~ s/nitter\.net/twitter\.com/;

        if (defined &URLIdentifier::url_id) {
            URLIdentifier::url_id("RSS.pm", "0.0.0.0", $chan, $tmplink);
            rss_dbwrite($db);
            return;
        }

      } elsif ($tmplink =~ /patriots\.win/) {
        if (defined &URLIdentifier::url_id) {
            URLIdentifier::url_id("RSS.pm", "0.0.0.0", $chan, $tmplink);
            rss_dbwrite($db);
            return;
        }
    }

      @tokens = split(/ /, encode_utf8($fmtstring));

      for (my $i = 0; $i < scalar @tokens; $i++) {
        if ($tokens[$i] =~ /\%FEED\%/) {
          $tokens[$i] =~ s/\%FEED\%/$title/;
        }
        elsif ($tokens[$i] =~ /\%TITLE\%/) {
          $tmptitle = $entry->title();
          utf8::decode($tmptitle);
          chomp $tmptitle;

          $tokens[$i] =~ s/\%TITLE\%/$tmptitle/;
        }
        elsif ($tokens[$i] =~ /\%URL\%/) {
          $tokens[$i] =~ s/\%URL\%/$tmplink/;
        } elsif ($tokens[$i] =~ /\%C\%/) {
          $tokens[$i] =~ s/\%C\%/\003/;
        } elsif ($tokens[$i] =~ /\%B\%/) {
          $tokens[$i] =~ s/\%B\%/\002/;
        }
      }

      $fmtstring = join(" ", @tokens);
      utf8::decode($fmtstring);
      chomp $fmtstring;
      $fmtstring =~ s/\n//gs;
      $fmtstring =~ s/^\s+|\s+$|\s+(?=\s)//g;

      
      $bot->say($chan, $fmtstring, 3);
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
        $bot->log("RSS: Refreshing feed $title for $chan", "Modules");
        $db->{$chan}->{$title}->{lastSync} = time();
        rss_dbwrite($db);

        if (!$feedcache{$db->{$chan}->{$title}->{url}}) {
          $ua->get($db->{$chan}->{$title}->{url} => {Accpet => '*/*'} => sub {
            my ($ua, $tx) = @_;

            if (my $err = $tx->error) {
              return $bot->err("RSS: Error fetching RSS feed $title [$db->{$chan}->{$title}->{url}] for $chan: ".$err->{message}, 0);
            }

            my $body = \scalar($tx->res->body);
            my $parsedfeed;


            $feedcache{$db->{$chan}->{$title}->{url}} = $body;
            rss_agrigator($body, $title, $chan);
          });

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
  $bot->unregister("RSS");

  $bot->log("[RSS] Unloading RSS module", "Modules");
  $bot->del_handler('event connected', 'rss_connected');
  $bot->del_handler('event tick', 'rss_tick');
  $bot->del_handler('privcmd rss', 'rss_irc_interface');

  $help->del_help("rss", "Channel");
}

1;
