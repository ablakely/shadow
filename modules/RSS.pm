# RSS - Shadow RSS Module
# v1.1
# Written by Aaron Blakely <aaron@ephasic.org>
#
# Changelog:
# v1.1 - Performance and feed compatibility improvements, formatting support
# v1.2 - Switch to Shadow::DB
#
# feed.db format:
# [
#   "#chan": {
#     "title": {
#       url: "",
#       "format": "%FEED%: %TITLE% [%URL%]",
#       lastSync: epoch,
#       syncInterval: seconds,
#       autoSync: 1,
#       fetchMeta: 1,
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
use Time::Seconds;
use Mojo::IOLoop;
use Mojo::UserAgent;
use XML::Feed;
use utf8;
use POSIX;
use JSON;
use Encode qw( encode_utf8 );

use Shadow::DB;
use Shadow::Core;
use Shadow::Help;
use Shadow::Formatter;


my $bot      = Shadow::Core->new();
my $help     = Shadow::Help->new();
my $dbi      = Shadow::DB->new();
my $ua       = Mojo::UserAgent->new;
my %feedcache;
my $web;

my %reqstats;
my %failedreqstats;
$reqstats{_stathour} = strftime("%I %p", gmtime(time));
$reqstats{_statday}  = (gmtime(time))[3];

sub loader {
    $bot->register("RSS", "v1.1", "Aaron Blakely", "RSS aggregator");

    if ($bot->storage_exists("RSS.reqstats")) {
        %reqstats = %{ $bot->retrieve("RSS.reqstats") };
        %failedreqstats = %{ $bot->retrieve("RSS.failedreqstats") };
    }

    $bot->log("[RSS] Loading: RSS module v1.1", "Modules");
    $bot->add_handler('event connected', 'rss_connected');
    $bot->add_handler('privcmd rss', 'rss_irc_interface');
    $help->add_help("rss", "Channel", "<add|del|list|set|sync> [#chan] [feed name] [url]", "RSS module interface.", 0, sub {
        my ($nick, $host, $text) = @_;
        my @out;

        my $cmdprefix = "/msg $Shadow::Core::nick ";
        $cmdprefix    = "/" if ($bot->is_term_user($nick));

        if ($text =~ /rss set/i) {
            push(@out, "Help for \x02RSS SET\x02:");
            push(@out, " ");
            push(@out, "\x02SYNTAX\x02: ${cmdprefix}rss set <option> <chan> <feed name> <value>");

            push(@out, " ");
            push(@out, "  Options:");
            push(@out, "    SYNCTIME - Refresh rate for a feed in seconds.");
            push(@out, "    FORMAT   - Change the output format for a feed:");
            push(@out, "      Example: \%FEED\%: \%TITLE\% [\%URL\%]");
            push(@out, "      ");
            push(@out, "      \%FEED\%: Feed name");
            push(@out, "      \%TITLE\%: RSS entry title");
            push(@out, "      \%URL\%: RSS entry link");
            push(@out, "      \%C\%: mIRC color escape character (ctrl + k)");
            push(@out, "      \%B\%: mIRC bold character (ctrl + b)");

            $bot->fastsay($nick, @out);

            return;
        }

        push(@out, "Help for \x02RSS\x02:");
        push(@out, " ");
        push(@out, "\x02rss\x02 is a command used for managing rss feeds for each channel.");
        push(@out, "this command uses subcommands to perform different actions:");
        push(@out, "  \x02add\x02 #chan <feed name> <url> - adds a feed for a channel.");
        push(@out, "  \x02del\x02 #chan <feed name> - removes a feed from a channel.");
        push(@out, "  \x02set\x02 #chan <feed name> <setting> <value> - not yet implemented.");
        push(@out, "  \x02list\x02 #chan - lists all of the feeds for a given channel.");
        push(@out, "  \x02sync\x02 - forces the bot to sync all feeds.");
        push(@out, " ");
        push(@out, "\x02syntax\x02: ${cmdprefix}rss <add|del|list|set|sync> [#chan] [feed name] [url]");


        $bot->fastsay($nick, @out);
    });

    my $db = ${$dbi->read("feeds.db")};
    if (!scalar(keys(%{$db}))) {
        $dbi->write();
    }

    $ua->transactor->name("'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36'");

    rss_connected() if ($bot->connected());

    # WebAdmin extension
    if ($bot->isloaded("WebAdmin")) {
        $web = WebAdmin->new();
        my $router = $web->router();

        $web->add_navbar_link("/rss", "rss", "RSS");
        $router->get('/rss', sub {
            my ($client, $params, $headers) = @_;
            my $db = ${$dbi->read("feeds.db")};

            my @chanlinks;

            foreach my $chan (keys(%{$db})) {
                $chan =~ s/\#//;
                push(@chanlinks, {
                    text => $chan,
                    link => "/rss?view=$chan",
                    icon => "hash"
                });
            }

            if ($web->checkSession($headers)) {

                if (exists($params->{deleteChan})) {
                    $params->{deleteChan} = "#".$params->{deleteChan}; 

                    if (exists($db->{$params->{deleteChan}})) {
                        delete $db->{$params->{deleteChan}};
                        $dbi->write();
                    }
                    
                    return $router->redirect($client, '/rss');
                } elsif (exists($params->{chan}) && exists($params->{deleteFeed})) {
                    $params->{chan} = "#".$params->{chan}; 

                    if (exists($db->{$params->{chan}}->{$params->{deleteFeed}})) {
                        delete $db->{$params->{chan}}->{$params->{deleteFeed}};
                        $dbi->write();
                    }
                    
                    return $router->redirect($client, '/rss?view='.$params->{chan});
                } elsif (exists($params->{chan}) && exists($params->{toggleAutoSync})) {
                    $params->{chan} = "#".$params->{chan}; 

                    if (exists($db->{$params->{chan}}->{$params->{toggleAutoSync}}->{autoSync})) {
                        $db->{$params->{chan}}->{$params->{toggleAutoSync}}->{autoSync} = $db->{$params->{chan}}->{$params->{toggleAutoSync}}->{autoSync} ? 0 : 1;
                        $dbi->write();
                    }

                    $params->{chan} = substr($params->{chan}, 1, length($params->{chan}));

                    return $router->redirect($client, '/rss?view='.$params->{chan});
                } elsif (exists($params->{view})) {
                    $params->{view} = "#".$params->{view};

                    my @dbk = sort(keys(%{$db->{$params->{view}}}));

                    $router->headers($client);
                    return $web->out($client, $web->render("mod-rss/view.ejs", {
                        nav_active => "RSS",
                        show_quicklinks => 1,
                        quicklinks_header => "Channels",
                        quicklinks => \@chanlinks,
                        chan => $params->{view},
                        db => $db->{$params->{view}},
                        dbk => \@dbk,
                        gmtime => sub { return "".gmtime(shift())." GMT"; },
                        supportedURL => sub { return 0 if (!$bot->isloaded("URLIdentifier")); return URLIdentifier::is_supported(shift()); }
                    }));
                } else {
                    my @labels;
                    my $label;

                    foreach $label (sortTimeStampArray(keys(%reqstats))) {
                        next if ($label =~ /^\_/);
                        push(@labels, $label);
                    }
                    
                    my @data;
                    my @failed;

                    foreach my $label (@labels) {
                        next if ($label =~ /^\_/);
                        push(@data, $reqstats{$label});
                        push(@failed, exists($failedreqstats{$label}) ? $failedreqstats{$label} : 0); 
                    }
                    
                    my $labelstr = to_json(\@labels);
                    my $datastr  = to_json(\@data);
                    my $failedstr= to_json(\@failed);
                    my $totalfeeds = 0;

                    foreach my $chan (keys(%{$db})) {
                        $totalfeeds += scalar(keys(%{$db->{$chan}}));
                    }


                    $router->headers($client);
                    return $web->out($client, $web->render("mod-rss/index.ejs", {
                        nav_active => "RSS",
                        show_quicklinks => 1,
                        quicklinks_header => "Channels",
                        quicklinks => \@chanlinks,
                        labels => $labelstr,
                        data   => $datastr,
                        failed => $failedstr,
                        totalfeeds => $totalfeeds,
                        chancount  => scalar(keys(%{$db}))
                    }));
                } 

            } else {
                return $router->redirect($client, "/");
            }
        });

        $router->post('/rss-edit', sub {
            my ($client, $params, $headers) = @_;
            my $db = ${$dbi->read("feeds.db")};

            if ($web->checkSession($headers)) {
                return $router->redirect($client, "/rss") unless (
                        exists($params->{editInputChan}) &&
                        exists($params->{editInputFeed}) &&
                        exists($params->{editInputURL})  &&
                        exists($params->{editInputSync}) &&
                        exists($params->{editInputFormat}));
                    
                my $feed = $params->{editInputFeed};
                my $chan = $params->{editInputChan};
                
                $db->{$chan}->{$feed}->{url} = $params->{editInputURL} ? $params->{editInputURL} : $db->{$chan}->{$feed}->{url};
                $db->{$chan}->{$feed}->{syncInterval} = $params->{editInputSync} ? $params->{editInputSync} : $db->{$chan}->{$feed}->{syncInterval};
                $db->{$chan}->{$feed}->{format} = $params->{editInputFormat} ? $params->{editInputFormat} : $db->{$chan}->{$feed}->{format};
                
                $dbi->write();
                $chan = substr($chan, 1, length($chan));
                return $router->redirect($client, "/rss?view=$chan");
            } else {
                return $router->redirect($client, '/');
            }
        });

        $router->post('/rss-chansettings', sub {

        });
    }

}

sub rss_connected {
  $bot->add_handler('event tick', 'rss_tick');
}

sub rss_irc_interface {
  my ($nick, $host, $text) = @_;
  my ($command, $arg1, $arg2, $arg3, @args) = split(" ", $text);
  my $db;
  my $cmdprefix = $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";

  if ($command eq "add" || $command eq "ADD") {
    if (!$arg1 || !$arg2 || !$arg3) {
      return $bot->notice($nick, "Syntax: ${cmdprefix}rss add <chan> <title> <url>");
    }

    if ($bot->isin($arg1, $Shadow::Core::nick) && $bot->isop($nick, $arg1)) {
      $db = ${$dbi->read("feeds.db")};
      $db->{lc($arg1)}->{$arg2} = {
        url => $arg3,
        lastSync => 0,
        syncInterval => 300,
        format => '%FEED%: %TITLE% [%URL%]',
        read => []
      };

      $dbi->write();
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
      $db = ${$dbi->read("feeds.db")};
      my $url = $db->{lc($arg1)}->{$arg2}->{url};
            
      delete($db->{lc($arg1)}->{$arg2});            
      $dbi->write();

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
      $db = ${$dbi->read("feeds.db")};
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
                      fmt_time($db->{$chan}->{$feed}->{syncInterval}),
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
                  fmt_time($db->{$arg1}->{$feed}->{syncInterval}),
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
        $db = ${$dbi->read("feeds.db")};
        $arg2 = lc($arg2);
        $db->{$arg2}->{$arg3}->{syncInterval} = $args[0];
        $dbi->write();

        $bot->notice($nick, "Updated sync interval to $args[0] for feed $arg3 in $arg2.");
        $bot->log("RSS: SET SYNCTIME was used by $nick for $arg3 in $arg2.", "Modules");
      }
    } elsif ($arg1 eq "FORMAT" || $arg1 eq "format") {
      return $bot->notice($nick, "\002SYNTAX\002: /msg $Shadow::Core::nick rss set FORMAT <chan> <feed> <format string>") if (!$arg2 || !$arg3 || !$args[0]);

      if ($bot->isin($arg2, $Shadow::Core::nick) && $bot->isop($nick, $arg2)) {
        $db = ${$dbi->read("feeds.db")};
        $arg2 = lc($arg2);
        $db->{$arg2}->{$arg3}->{format} = join(" ", @args);
        $dbi->write();

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

sub sortTimeStampArray {
    my (@arr) = @_;
    my (@AM, @PM, @AMR, @PMR);

    foreach my $v (@arr) {
        if ($v =~ /AM/) {
            push(@AM, $v);
        } elsif ($v =~ /PM/) {
            push(@PM, $v);
        }
    }

    @AM = sort(@AM);
    @PM = sort(@PM);

    foreach my $v (@AM) {
        if ($v =~ /12/) {
            unshift(@AMR, $v);
        } else {
            push(@AMR, $v);
        }
    }
    
    foreach my $v (@PM) {
        if ($v =~ /12/) {
            unshift(@PMR, $v);
        } else {
            push(@PMR, $v);
        }
    }

    my @ret = (@AMR, @PMR);

    return @ret;
}

sub calc_interval {
    my (@times) = @_;
    @times = reverse(@times);
    my $ltime = shift @times;

    my $total = 0;
    foreach my $time (@times) {
        my $interval = $time - $ltime;
        $ltime = $time;
        $total += $interval;
    }

    return $total;
}

sub fmt_time {
    my $seconds = shift;
    my $ret = "";
    
    my $days = int($seconds / (24 * 3600));
    $ret .= $days > 1 ? "$days days, " : "$days day, " if ($days);
    $seconds -= $days * 24 * 3600;

    my $hours = int($seconds / 3600);
    $ret .= $hours > 1 ? "$hours hours, " : "$hours hour, " if ($hours);
    $seconds -= $hours * 3600;

    my $minutes = int($seconds / 60);
    $ret .= $minutes > 1 ? "$minutes minutes, " : "$minutes minute, " if ($minutes);
    $seconds -= $minutes * 60;

    $ret .= $seconds > 1 ? "$seconds seconds" : "$seconds second" if ($seconds);    

    $ret =~ s/\, $/\ /s;

    return $ret;
}

sub rss_checkread {
    my ($chan, $title, $link) = @_;
    my $db = ${$dbi->read("feeds.db")};

    foreach my $post (@{$db->{$chan}->{$title}->{read}}) {
        if ($post->{url} eq $link) {
            return 1;
        }
    }
}

sub rss_updateread {
  my ($chan, $title, $link) = @_;
  my $db = ${$dbi->read("feeds.db")};

  for (my $i = 0; $i < scalar(@{$db->{$chan}->{$title}->{read}}); $i++) {
    if ($db->{$chan}->{$title}->{read}->[$i]->{url} eq $link) {
      $db->{$chan}->{$title}->{read}->[$i]->{lastRecieved} = time();
    }
  }

  $dbi->write();
}

sub update_synctime {
    my ($chan, $title, @times) = @_;
    my $db = ${$dbi->read("feeds.db")};

    if (!exists($db->{$chan}->{$title}->{autoSync})) {
        $db->{$chan}->{$title}->{autoSync} = 1;
    } elsif ($db->{$chan}->{$title}->{autoSync} == 1) {
        my $freq = calc_interval(@times);

        if ($freq < 400) {
            $freq = 400;
        } elsif ($freq > 1320) {
            $freq = 1320;
        }

        my $db = ${$dbi->read("feeds.db")};
        if (exists($db->{$chan}->{$title})) {
            $bot->log("RSS: Updating SYNCTIME for feed [$title:$chan] to $freq", "Modules");
            $db->{$chan}->{$title}->{syncInterval} = "$freq";
            return $dbi->write();
        }
    }

    return 0;
}

sub rss_agrigator {
  my ($rawxml, $title, $chan) = @_;
  my $db = ${$dbi->read("feeds.db")};

  my @times;
  my $parsedfeed = XML::Feed->parse($rawxml) or return $bot->err("RSS: Parser error on feed $title: ".XML::Feed->errstr, 0);
  for my $entry ($parsedfeed->entries) {
    my $fmtstring = $db->{$chan}->{$title}->{format};
    my $tmplink = $entry->link();
    my $read = rss_checkread($chan, $title, $tmplink);

    my $issued = $entry->issued();
    push(@times, $issued->epoch()) if ($issued);

    my $tmptitle;
    my @tokens;

    if (!$read) {
        $db = ${$dbi->read("feeds.db")};

        push(@{$db->{$chan}->{$title}->{read}}, {
            url => $tmplink,
            lastRecieved => time()
        });

        $dbi->write();

        if ($bot->isloaded("URLIdentifier")) {
            $tmplink =~ s/nitter\.net/twitter\.com/;
            if (URLIdentifier::is_supported($tmplink)) {
                if (!exists($db->{$chan}->{$title}->{fetchMeta})) {
                    $db->{$chan}->{$title}->{fetchMeta} = 1;
                    $dbi->write();
                }

                if ($db->{$chan}->{$title}->{fetchMeta}) {
                    $reqstats{$reqstats{_stathour}}++;
                    
                    URLIdentifier::url_id("RSS.pm", "0.0.0.0", $chan, $tmplink);
                    $dbi->write();

                    update_synctime($chan, $title, @times);
                    return;
                }
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

  # calculate SYNCTIME
  update_synctime($chan, $title, @times);
  $dbi->write();
}

sub rss_refresh {
  my $db = ${$dbi->read("feeds.db")};

  foreach my $chan (keys %{$db}) {
    foreach my $title (keys %{$db->{$chan}}) {
      my $synctime = $db->{$chan}->{$title}->{lastSync} + $db->{$chan}->{$title}->{syncInterval};

      if (time() >= $synctime) {
        $bot->log("RSS: Refreshing feed $title for $chan", "Modules");
        $db->{$chan}->{$title}->{lastSync} = time();
        $dbi->write();

        if (!$feedcache{$db->{$chan}->{$title}->{url}}) {
          $reqstats{$reqstats{_stathour}}++;
          $ua->get($db->{$chan}->{$title}->{url} => {Accpet => '*/*'} => sub {
            my ($ua, $tx) = @_;

            if (my $err = $tx->error) {
              $failedreqstats{$reqstats{_stathour}}++;
              $reqstats{$reqstats{_stathour}}--;
              return $bot->err("RSS: Error fetching RSS feed $title [$db->{$chan}->{$title}->{url}] for $chan: ".$err->{message}, 0);
            }

            my $body = \scalar($tx->res->body);
            my $parsedfeed;


            $feedcache{$db->{$chan}->{$title}->{url}} = $body;
            rss_agrigator($body, $title, $chan);
          });

          my $rss_feed = $ua->get_p($db->{$chan}->{$title}->{url});

          Mojo::Promise->all($rss_feed)->then(sub($rss) {
            return if (!$rss);

            if (my $err = $rss->error) {
              $failedreqstats{$reqstats{_stathour}}++;
              $reqstats{$reqstats{_stathour}}--;
              return $bot->err("RSS: Error fetching RSS feed $title for $chan: ".$err->{message}, 0);
            }

            my $body = \scalar($rss->[0]->result->body);

            my $parsedfeed;

            $feedcache->{$db->{$chan}->{$title}->{url}} = $body;
            rss_agrigator($body, $title, $chan);
          })->catch(sub {
              $failedreqstats{$reqstats{_stathour}}++;
              $reqstats{$reqstats{_stathour}}--;
              return $bot->err("RSS: Error fetching RSS feed $title for $chan: ".shift(), 0);
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

  if (strftime("%I %p", gmtime(time)) ne $reqstats{_stathour}) {
      $reqstats{_stathour} = strftime("%I %p", gmtime(time));
  }

  if ((gmtime(time))[3] != $reqstats{_statday}) {
      %reqstats = ();
      %failedreqstats = ();
      $reqstats{_statday} = (gmtime(time))[3];
      $reqstats{_stathour} = strftime("%I %p", gmtime(time));
  }
}

sub unloader {
  $bot->unregister("RSS");

  $bot->log("[RSS] Unloading RSS module", "Modules");
  $bot->del_handler('event connected', 'rss_connected');
  $bot->del_handler('event tick', 'rss_tick');
  $bot->del_handler('privcmd rss', 'rss_irc_interface');

  $help->del_help("rss", "Channel");
  
  $bot->store("RSS.reqstats", \%reqstats);
  $bot->store("RSS.failedreqstats", \%failedreqstats);

  if ($bot->isloaded("WebAdmin")) {
    my $router= $web->router();
    $web->del_navbar_link("RSS");
    $router->del('get', '/rss');
    $router->del('post', '/rss-edit');
    $router->del('post', '/rss-chansettings');
  }
}

1;
