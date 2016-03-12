package URLIdentifier;

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
    		die $response->status_line;
	}
}

sub url_id {
  my ($nick, $host, $chan, $text) = @_;

  if ($text =~ /^[http\:\/\/|https\:\/\/]/) {
    my $title = getTitle($text);
    $bot->say($chan, "Title: $title") if $title;
  }
}

sub unloader {
  $bot->del_handler('message channel', 'url_id');
}

1;

