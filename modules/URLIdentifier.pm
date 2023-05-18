package URLIdentifier;

# Shadow Module: URLIdentifier
# Automatic URL title/meta fetching
#
# Supported sites for metadata parsing:
#  youtube.com, youtu.be
#  twitter.com, nitter.net
#  browser.geekbench.com
#  ebay.com
#  reddit.com
#  patriots.win
#  rumble.com
#  odysee.com
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Change Log:
#   6/22/22 - Updated to give more details about videos from Odysee and Youtube
#   4/11/23 - Strip <a> tags out of tweets
#             Fix ebay scraping
#   5/18/23 - Added rumble.com scraping



use utf8;
use JSON;
use Encode qw( encode_utf8 );
use LWP::UserAgent;
use open qw(:std :encoding(UTF-8));

our $bot  = Shadow::Core;
our $help = Shadow::Help;

sub loader {
  $bot->register("URLIdentifier", "v1.5", "Aaron Blakely");

  $bot->add_handler('message channel', 'url_id');
}

sub getSiteInfo {
	my ($url) = @_;

	my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
  $ua->agent("'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36'");

  $url =~ s/twitter\.com/nitter\.net/; # nitter ftw

	my $response = $ua->get($url);

  my ($title, %meta);
  my $gbNote;

	if ( $response->is_success ) {
    my $htmlResp =  $response->decoded_content({charset => 'utf-8'});
    chomp $htmlResp;
    if ($url =~ /odysee\.com/ && $htmlResp =~ /\<script type\=\"application\/ld\+json\"\>(.*?)\<\/script\>/gsi) {
      my $jsonstr = $1;
      $jsonstr =~ s/\x{fffd}//gs;
      $jsonstr =~ s/\n//gs;
      $jsonstr =~ s/\r//gs;
      $jsonstr =~ s/\t//gs;
      $jsonstr =~ s/\\n/ /gs;
      $jsonstr =~ s/\x{00a0}//gs;
      chomp $jsonstr;

      $jsonstr = encode_utf8($jsonstr);
      my $metaSchema = from_json($jsonstr, { utf8 => 1 });

      $meta{'name'} = $metaSchema->{name};
      $meta{'description'} = $metaSchema->{description};
      $meta{'uploadDate'} = $metaSchema->{uploadDate};
      $meta{'duration'} = $metaSchema->{duration};
      $meta{'channelName'} = $metaSchema->{author}->{name};

      if ($meta{'uploadDate'} =~ /(\d+)\-(\d+)\-(\d+)T(\d+)\:(\d+)\:(\d+).(\d+)Z/) {
        $meta{'uploadDate'} = "$1-$2-$3";
      }
    }

    $htmlResp =~ s/\n//gs;
    $htmlResp =~ s/\r//gs;
    $htmlResp =~ s/\&nbsp\;//gs;

    # pdw

    if ($url =~ /patriots\.win\/p/ && $htmlResp =~ /\<span class="positive"\>\+\<span\>(.*?)<\/span\>\<\/span\> \/ \<span class="negative"\>\-\<span\>(.*?)<\/span><\/span\>/) {
      $meta{'upvotes'} = $1;
      $meta{'downvotes'} = $2;
    }

    if ($url =~ /patriots\.win\/p/ && $htmlResp =~ /\<span class="post-flair" data-flair=\"(.*?)\"\>(.*?)<\/span\>/) {
      $meta{'flairtype'} = $1;
      $meta{'flair'} = $2;

      $meta{'flair'} =~ s/\&nbsp\;|\s{3,}//gis; 
    }

    # rumble
    if ($url =~ /rumble\.com/ && $htmlResp =~ /\<h1.*?\>(.*?)\<\/h1\>/) {
      print "dbug title: $1\n";
      $meta{'title'} = $1;
    }

    if ($url =~ /rumble\.com/ && $htmlResp =~ /\<span class="rumbles-up-votes"\>(.*?)\<\/span\>/) {
      $meta{'upvotes'} = $1;
    }

    if ($url =~ /rumble\.com/ && $htmlResp =~ /\<span class="rumbles-down-votes"\>(.*?)\<\/span\>/) {
      $meta{'downvotes'} = $1;
    }

    if ($url =~ /rumble\.com/ && $htmlResp =~ /\<div class="video-counters--item video-item--views"\>[[:space:]]?[\s]*?\<svg.*?\<\/svg\>(.*?)[\s]*?\<\/div\>/) {
      $meta{'views'} = $1;
    }

    if ($url =~ /rumble\.com/ && $htmlResp =~ /\<div class="video-counters--item video-item--comments"\>[[:space:]]?[\s]*?\<svg.*?\<\/svg\>(.*?)[\s]*?\<\/div\>/) {
      $meta{'comments'} = $1;
    }

    # geekbench page scraping

    if ($url =~ /browser\.geekbench\.com/ && $htmlResp =~ /\<meta name\=\"description\" content=\"(.*?)\"\>/gis) {
      $meta{'description'} = $1;
      chomp $meta{'description'};
    }

    if ($url =~ /reddit\.com/ && $htmlResp =~ /\<meta name\=\"description\" content=\"(.*?)\"\/\>/gis) {
      $meta{'description'} = $1;
      chomp $meta{'description'};
    }

    if ($url =~ /browser\.geekbench\.com/ && $htmlResp =~ /\<div class\=\'score\'\>(\d+)\<\/div\>\<div class\=\'note\'\>Single-Core Score\<\/div\>/gis) {
      $meta{'singleCoreScore'} = $1;
      chomp $meta{'singleCoreScore'};
    }

    if ($url =~ /browser\.geekbench\.com/ && $htmlResp =~ /\<div class\=\'score\'\>(\d+)\<\/div\>\<div class\=\'note\'\>Multi-Core Score\<\/div\>/gis) {
      $meta{'multiCoreScore'} = $1;
      chomp $meta{'multiCoreScore'};
    }

    if ($url =~ /browser\.geekbench\.com/ && $htmlResp =~ /\<td class\=\'system-name\'\>Topology\<\/td\>\<td class\=\'system-value\'\>(.*?)\<\/td\>/gis) {
      $meta{'topology'} = $1;
      chomp $meta{'topology'};
    }

    if ($url =~ /browser\.geekbench\.com/ && $htmlResp =~ /\<td class\=\'system-name\'\>Memory\<\/td\>\<td class\=\'system-value\'\>(.*?)\<\/td\>/gis) {
      $meta{'mem'} = $1;
      chomp $meta{'mem'};
    }

    if ($url =~ /nitter\.net/ && $htmlResp =~ /\<div class\=\"tweet-content media-body\" dir\=\"auto\"\>(.*?)\<\/div\>/si && !$meta{'tweet'}) {
      $meta{'tweet'} = $1;

      if ($meta{'tweet'} =~ /\<a(.*?)\>(.*?)\<\/a\>/gi) {
        my $atag = $1;
        my $visible = $2;
        $meta{'tweet'} =~ s/\<a$atag\>$visible\<\/a\>/$visible/gs;
      }
    }

    if ($htmlResp =~ /\<title\>(.*)\<\/title\>/) {
      $title = $1;
    }

    my @html = split(/\>/, $htmlResp);

		for (my $i = 0; $i < $#html; $i++) {
      chomp $line;
      chomp $nl;

      my $line = $html[$i].">";
      my $nl = $html[$i+1].">";
      my $nl2 = $html[$i+2].">";
      my $nl3 = $html[$i+3].">";
      my $nl4 = $html[$i+4].">";
      my $nl5 = $html[$i+5].">";
      my $nl6 = $html[$i+6].">";
    
      $nl =~ s/\n/ /gs;
      $nl =~ s/\r//gs;


      if ($url =~ /ebay\.[[:alpha:]]/ && $line =~ /https\:\/\/www.ebay.com\/usr\/(.*?)\?/gsi) {
        $meta{'seller'} = $1;
      }

      if ($url =~ /ebay\.[[:alpha:]]/ && $line =~ /\<span itemprop\=price content\=(.*?)\>/gsi) {
        $meta{'price'} = $nl6;
        $meta{'price'} =~ s/\<\!--F\/--\>//gs;
      }

      if ($url =~ /ebay\.[[:alpha:]]/ && $line =~ /\"accessibilityText\"\:\"(\d+)\(feedback score\)\"/gsi) {
        $meta{'feedbackScore'} = $1;
      }

      if ($line =~ /\<meta itemprop\=\"(\w+)\" content=\"(.*)\"\>/gis) {
        $meta{$1} = $2;
      }

      if ($url =~ /browser\.geekbench\.com/ && $line =~ /\<td class\=\'system-name\'\>/gis && $nl =~ /(.*?)\<\/td\>/gis) {
        my $param = $1;

        my ($lp2, $lp3) = ($html[$i+2].">", $html[$i+3].">");

        if ($lp2 =~ /\<td class\=\'system-value\'\>/gis && $lp3 =~ /(.*?)\<\/td\>/gis) {
          print "$param = $1 $2\n";

          $meta{$param} = $1;
          chomp $meta{$param};
        }
      }
      
      # nitter page scraping

      if ($url =~ /nitter\.net/ && $line =~ /\<p class\=\"tweet-published\"\>/gsi && $nl =~ /(.*?)\<\/p\>/gsi && !$meta{'published'}) {
        $meta{'published'} = $1;
      }

      if ($url =~ /nitter\.net/ && $line =~ /\<a class\=\"fullname\" href\=\"(.*?)\" title\=\"(.*?)\"\>/gsi && !$meta{'username'} && !$meta{'fullname'}) {
        $meta{'username'} = $1;
        $meta{'fullname'} = $2;

        $meta{'username'} =~ s/\//\@/;
      }

      if ($url =~ /nitter\.net/ && $line =~ /\<span class\=\"icon-comment\" title\=\"\"\>/gsi && $nl =~ /\<\/span\>/gsi && !$meta{'comments'}) {
        $meta{'comments'} = $nl2;
        $meta{'comments'} =~ s/^\s//;
        $meta{'comments'} =~ s/\<\/div\>$//;
      }
      if ($url =~ /nitter\.net/ && $line =~ /\<span class\=\"icon-retweet\" title\=\"\"\>/gsi && $nl =~ /\<\/span\>/gsi && !$meta{'retweets'}) {
        $meta{'retweets'} = $nl2;
        $meta{'retweets'} =~ s/^\s//;
        $meta{'retweets'} =~ s/\<\/div\>$//;
      }
      if ($url =~ /nitter\.net/ && $line =~ /\<span class\=\"icon-quote\" title\=\"\"\>/gsi && $nl =~ /\<\/span\>/gsi && !$meta{'quotetweets'}) {
        $meta{'quotetweets'} = $nl2;
        $meta{'quotetweets'} =~ s/^\s//;
        $meta{'quotetweets'} =~ s/\<\/div\>$//;
      }
      if ($url =~ /nitter\.net/ && $line =~ /\<span class\=\"icon-heart\" title\=\"\"\>/gsi && $nl =~ /\<\/span\>/gsi && !$meta{'likes'}) {
        $meta{'likes'} = $nl2;
        $meta{'likes'} =~ s/^\s//;
        $meta{'likes'} =~ s/\<\/div\>$//;
      }
		}



    $title =~ s/\&quot;/\"/g;
    $title =~ s/\&\#39\;/\'/g;
    $title =~ s/\&amp;/\&/g;
    $title =~ s/\&lt;/\</g;
    $title =~ s/\&gt;/\>/g;
    $title =~ s/\&\#039\;/\'/g;
    $title =~ s/\&\#x27;/\'/g;

    if ($meta{'name'}) {
      $meta{'name'} =~ s/\&quot;/\"/g;
      $meta{'name'} =~ s/\&\#39\;/\'/g;
      $meta{'name'} =~ s/\&amp;/\&/g;
      $meta{'name'} =~ s/\&lt;/\</g;
      $meta{'name'} =~ s/\&gt;/\>/g;
      $meta{'name'} =~ s/\&\#039\;/\'/g;
    }

    if ($meta{'description'}) {
      $meta{'description'} =~ s/\&quot;/\"/g;
      $meta{'description'} =~ s/\&\#39\;/\'/g;
      $meta{'description'} =~ s/\&amp;/\&/g;
      $meta{'description'} =~ s/\&lt;/\</g;
      $meta{'description'} =~ s/\&gt;/\>/g;
      $meta{'description'} =~ s/\&\#039\;/\'/g;
    }

    if ($title && !$meta{'description'}) {
      $meta{'description'} = $title;
    }

    if ($meta{'duration'}) {
      my $duration = "0:00";

      if ($meta{'duration'} =~ /PT(\d+)M(\d+)S/) {
        my $sec = int $2;

        if (int $sec < 10) {
          $sec = "0$sec";
        }

        if ($1 > 60) {
          my $hr = int $1 / 60;
          my $min = $1 % 60;
          $duration = "$hr:$min:$sec";
        } else {
          $duration = "$1:$sec";
        }
      }
      if ($meta{'duration'} =~ /PT(\d+)H(\d+)M(\d+)S/) {
        $duration = "$1:$2:$3";
      }

      if ($duration eq "0:00") {
        $duration = "\x0304LIVE\x03";
      }

      $meta{'duration'} = $duration;
    }

    return ($title, %meta);
	} else {
    $bot->err("URLIdentifier: Error fetching title for $url: ".$response->status_line, 0);
	}
}


sub getReturnDislikeCounts {
  my ($url) = @_;
  $url =~ s/(http\:\/\/|https\:\/\/)(www.youtube.com|youtube.com|youtu.be)(\/watch\?v\=|\/)//;
  $url = "https://returnyoutubedislikeapi.com/Votes?videoId=$url";

  my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
  $ua->agent("'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36'");

  my $response = $ua->get($url);

	if ( $response->is_success ) {
    my $htmlResp = $response->decoded_content({charset => 'utf-8'});
    my $respObj =  from_json(encode_utf8($htmlResp), { utf8 => 1 });

    return $respObj;
  }
}

sub shortenURL {
  my ($url) = @_;

  my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );

  my $response = $ua->get("https://v.gd/create.php?format=simple&url=".$url);
  if ( $response->is_success ) {
    return $response->decoded_content();
  } else {
    return $url;
  }
}

sub url_id {
  my ($nick, $host, $chan, $text) = @_;

  my @tmp;

  return if ($text =~ /facebook\.com/);
  return if ($text =~ /\.png|\.jpg|\.jpeg$/gsi);

  if ($text =~ /(http\:\/\/|https\:\/\/)(.*)/) {
    my $url = "$1$2";

    if ($url =~ /ebay\.[[:alpha:]]\/itm\/(\d+)\?(.*)$/) {
      $url = "https://www.ebay.$1/itm/$2";
    }

    my ($title, %meta) = getSiteInfo($url);

    $bot->log("URLIdentifier: Fetching URL [$url] for $nick in $chan.", "Modules");

    if ($url =~ /ebay\.[[:alpha:]]/) {
      $title =~ s/\| eBay//;

      if ($meta{'price'} && $meta{'seller'} && $meta{'feedbackScore'}) {
        $bot->say($chan, "[\x034e\x032B\x038a\x033y\x03] \x02Title:\x02 $title [\x02\x033Price:\x02 $meta{'price'} | \x02Seller:\x02 $meta{'seller'} (\x02Feedback Score:\x02 $meta{'feedbackScore'})\x03]");
      } else {
        $bot->say($chan, "[\x034e\x032B\x038a\x033y\x03] $title");
      }
    } elsif ($url =~ /youtube\.com/ || $url =~ /youtu\.be/) {
      $title  =~ s/- YouTube$//;

      my $ytReactions = getReturnDislikeCounts($url);
      if ($ytReactions->{likes} && $ytReactions->{dislikes}) {
        $bot->say($chan, "\x030,4 ▶ \x03 \x02Title:\x02 \x02\x0304$meta{'name'}\x03\x02 \x02Description:\x02 $meta{'description'} [\x02\x0310Views:\x02 $meta{'interactionCount'} | \x02Likes:\x02 $ytReactions->{likes} | \x02Dislikes:\x02 $ytReactions->{dislikes} | \x02Date:\x02 $meta{'datePublished'} | \x02Duration:\x02 $meta{'duration'}\x03]");
      } else {
        $bot->say($chan, "\x030,4 ▶ \x03 \x02Title:\x02 \x02\x0304$meta{'name'}\x03\x02 \x02Description:\x02 $meta{'description'} [\x02\x0310Views:\x02 $meta{'interactionCount'} | \x02Date:\x02 $meta{'datePublished'} | \x02Duration:\x02 $meta{'duration'}\x03]");
      }
    } elsif ($url =~ /github\.com/) {
      $title =~ s/^GitHub - //;
      $bot->say($chan, "[\x030,1\x02GitHub\x02 \x{1F431}\x03] $title");
    } elsif ($url =~ /reddit\.com/) {
      my $subreddit = "";

      if ($title =~ /(.*?) \: (\w+)/) {
        $title = $1;
        $subreddit = "\x0307/r/$2\x03";
      }
      if ($meta{'description'} =~ /(.*?) votes\, (\d+) comments. (.*?) members in the (.*?) community\. (.*)/ && $subreddit ne "") {
        $bot->say($chan, "[\x02redd\x0307i\x03t $subreddit] $title\x02 [\x0307\x02Votes:\x02 $1 | \x02Comments:\x02 $2 | \x02Sub Description ($3 members):\x02 $5\x03]");
      } else {
        $bot->say($chan, "[\x02redd\x0307i\x03t]\x02 $title");
      }
    } elsif ($url =~ /odysee\.com/) {
      $bot->say($chan, "[\x037\x02Odysee\x02 \x{1F680}\x03] \x02Title:\x02 \x02\x037$meta{'name'}\x03\x02 \x02Description:\x02 $meta{'description'} [\x02\x036Channel:\x02 $meta{'channelName'} | \x02Date:\x02 $meta{'uploadDate'} | \x02Duration:\x02 $meta{'duration'}\x03]");
    } elsif ($text =~ /browser\.geekbench\.com/) {
      $bot->say($chan, "[\x0312Geekbench\x03] \x02\x0312$meta{'description'}\x03\x02 [\x02\x039Model:\x02 $meta{'Model'} | \x02Single Core:\x02 $meta{'singleCoreScore'} | \x02Multi Core:\x02 $meta{'multiCoreScore'} | \x02Topology:\x02 $meta{'topology'} | \x02RAM:\x02 $meta{'mem'} | \x02OS:\x02 $meta{'Operating System'}\x03]");
    } elsif ($url =~ /twitter\.com/) {
      if (!$meta{'comments'}) { $meta{'comments'} = 0; }
      if (!$meta{'retweets'}) { $meta{'retweets'} = 0; }
      if (!$meta{'quotetweets'}) { $meta{'quotetweets'} = 0; }
      if (!$meta{'likes'}) { $meta{'likes'} = 0; }

      $meta{'tweet'} =~ s/\<a href\=\"(.*?)\"\>(.*?)\<\/a\>/$2/gs;

      # shorten tweet
      if (length $meta{'tweet'} > 240) {
        $meta{'tweet'} = substr($meta{'tweet'}, 0, 240)."...";
      }

      # add spaces after punctuation
      $meta{'tweet'} =~ s/(.*?)([[:punct:]])([A-Z\#])/\1\2 \3/gs;

      if ($nick eq "RSS.pm" && $host eq "0.0.0.0") {
        $text = shortenURL($text);

        my $tweet = $meta{'tweet'} ? "[\x0311Twitter $meta{'username'}\x03] \x02$meta{'tweet'}\x02" : "[\x0311Twitter\x03]";
        my $author = $meta{'tweet'} ? "[\x02\x0311Author:\x02 $meta{'fullname'}" : "[\x02\x0311Author:\x02 $meta{'fullname'} ($meta{'username'})";

        if ($meta{'tweet'}) {
          $bot->raw("PRIVMSG $chan :$tweet\r\nPRIVMSG $chan :$author | \x02Comments:\x02 $meta{'comments'} | \x02Retweets:\x02 $meta{'retweets'} | \x02Quote Tweets:\x02 $meta{'quotetweets'} | \x02Likes:\x02 $meta{'likes'} | \x02Published:\x02 $meta{'published'}\x03] [\x02$text\x02]");
        } else {
          $bot->raw("PRIVMSG $chan :$tweet $author | \x02Comments:\x02 $meta{'comments'} | \x02Retweets:\x02 $meta{'retweets'} | \x02Quote Tweets:\x02 $meta{'quotetweets'} | \x02Likes:\x02 $meta{'likes'} | \x02Published:\x02 $meta{'published'}\x03] [\x02$text\x02]");
        }
      } else {
        $bot->say($chan, "[\x0311Twitter\x03] \x02$meta{'tweet'}\x02 [\x02\x0311Author:\x02 $meta{'fullname'} ($meta{'username'}) | \x02Comments:\x02 $meta{'comments'} | \x02Retweets:\x02 $meta{'retweets'} | \x02Quote Tweets:\x02 $meta{'quotetweets'} | \x02Likes:\x02 $meta{'likes'} | \x02Published:\x02 $meta{'published'}\x03]");
      }
    } elsif ($url =~ /nitter\.net/) {
      if (!$meta{'comments'}) { $meta{'comments'} = 0; }
      if (!$meta{'retweets'}) { $meta{'retweets'} = 0; }
      if (!$meta{'quotetweets'}) { $meta{'quotetweets'} = 0; }
      if (!$meta{'likes'}) { $meta{'likes'} = 0; }

      $meta{'tweet'} =~ s/\<a href\=\"(.*?)\"\>(.*?)\<\/a\>/$2/gs;
       
      $bot->say($chan, "[\x037nitter\x03] \x02$meta{'tweet'}\x02 [\x02\x037Author:\x02 $meta{'fullname'} ($meta{'username'}) | \x02Comments:\x02 $meta{'comments'} | \x02Retweets:\x02 $meta{'retweets'} | \x02Quote Tweets:\x02 $meta{'quotetweets'} | \x02Likes:\x02 $meta{'likes'} | \x02Published:\x02 $meta{'published'}\x03]");   
    } elsif ($url =~ /patriots\.win\/p/) {
      $title =~ s/\s+- The Donald - America First \| Patriots Win//;

      my $flairColor = "\x030,1";

      if ($meta{'flairtype'} eq "chopper") {
        $flairColor = "\x030,3";
      } elsif ($meta{'flairtype'} eq "sleepy") {
        $flairColor = "\x030,11";
      } elsif ($meta{'flairtype'} eq "violent" || $meta{'flairtype'} eq "didthat" || $meta{'flairtype'} eq "fchina") {
        $flairColor = "\x030,4";
      } elsif ($meta{'flairtype'} eq "stable") {
        $flairColor = "\x030,2";
      } elsif ($meta{'flairtype'} eq "henergy") {
        $flairColor = "\x030,6";
      } elsif ($meta{'flairtype'} eq "tread") {
        $flairColor = "\x030,8";
      } elsif ($meta{'flairtype'} eq "pocrime" || $meta{'flairtype'} eq "vfn") {
        $flairColor = "\x034,0";
      } elsif ($meta{'flairtype'} eq "yes" || $meta{'flairtype'} eq "geotus") {
        $flairColor = "\x030,8";
      } elsif ($meta{'flairtype'} eq "nuclear" || $meta{'flairtype'} eq "censored") {
        $flairColor = "\x034,1";
      } elsif ($meta{'flairtype'} eq "kek") {
        $flairColor = "\x030,3";
      } elsif ($meta{'flairtype'} eq "god") {
        $flairColor = "\x036,12";
      } elsif ($meta{'flairtype'} eq "reeee") {
        $flairColor = "\x030,12";
      }

      if ($meta{'flair'} ne "") {
        $meta{'flair'} =~ s/&#39;/'/gs;

        $meta{'flair'} = "\x02$flairColor\[".$meta{'flair'}."]\x03\x02";

        if ($nick eq "RSS.pm" && $host eq "0.0.0.0") {
          $bot->say($chan, "\x02\x034patriots\x0312.\x034win\x03\x02: \x02$title\x02 $meta{'flair'} [\x02\x039+$meta{'upvotes'}\x03 / \x034-$meta{'downvotes'}\x03\x02] [\x02\x0312$url\x03\x02]");
        } else {
          $bot->say($chan, "[\x034patriots\x0312.\x034win\x03] \x02$title\x02 $meta{'flair'} [\x02\x039+$meta{'upvotes'}\x03 / \x034-$meta{'downvotes'}\x03\x02]");
        }
      } else {
        if ($nick eq "RSS.pm" && $host eq "0.0.0.0") {
          $bot->say($chan, "\x02\x034patriots\x0312.\x034win\x03\x02: \x02$title\x02 [\x02\x039+$meta{'upvotes'}\x03 / \x034-$meta{'downvotes'}\x03\x02] [\x02\x0312$url\x03\x02]");
        } else {
          $bot->say($chan, "[\x034patriots\x0312.\x034win\x03] \x02$title\x02 [\x02\x039+$meta{'upvotes'}\x03 / \x034-$meta{'downvotes'}\x03\x02]");
        }
      }
    } elsif ($url =~ /rumble\.com/) {
      print "dbug: ".$meta{'title'}."\n";
      $bot->say($chan, "[\x039▶ rumble\x03] \x02$meta{'title'}\x02 [\x02\x039Views: $meta{'views'} | Upvotes: $meta{'upvotes'} | Downvotes: $meta{'downvotes'} | Comments: $meta{'comments'}\x03\x02]");
    } else {
      $title =~ s/\<\/title\>(.*)//gs;
      $bot->say($chan, "\x02Title:\x02 $title") if $title;
    }
  }
}

sub unloader {
  $bot->unregister("URLIdentifer");

  $bot->del_handler('message channel', 'url_id');
}


1;