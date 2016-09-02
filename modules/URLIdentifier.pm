package URLIdentifier;

# Shadow Module: URLIdentifier
# Automatic URL title fetching.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use LWP::UserAgent;
use open qw(:std :utf8);

our $bot  = Shadow::Core;
our $help = Shadow::Help;

sub loader {
  $bot->add_handler('message channel', 'url_id');
}

sub getTitle {
	my ($url) = @_;

	my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
	my $response = $ua->get($url);

	if ( $response->is_success ) {
    		my @html =  $response->decoded_content;

		foreach my $line (@html) {
			if ($line =~ /\<title\>(.*)\<\/title\>/) {
				return $1;
			}
		}
	}
	else {
    $bot->err("URLIdentifier: Error fetching title for $url: ".$response->status_line, 0);
	}
}

sub url_id {
  my ($nick, $host, $chan, $text) = @_;

  if ($text =~ /(^http\:\/\/|^https\:\/\/)/) {
    $bot->log("URLIdentifier: Fetching URL [$text] for $nick in $chan.");
    my $title = getTitle($text);
    $bot->say($chan, "Title: $title") if $title;
  }
}

sub unloader {
  $bot->del_handler('message channel', 'url_id');
}

1;
