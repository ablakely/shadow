package CCP;

use utf8;
my $bot = Shadow::Core;

our $leader = "
	⣿⣿⣿⣿⣿⠟⠋        ⠈⢻⢿⣿⣿⣿⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⠃           ⠈ ⠭⢿⣿⣿⣿⣿
	⣿⣿⣿⣿⡟ ⢀⣾⣿⣿⣿⣷⣶⣿⣷⣶⣶⡆   ⣿⣿⣿⣿
	⣿⣿⣿⣿⡇⢀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧  ⢸⣿⣿⣿⣿
	⣿⣿⣿⣿⣇⣼⣿⣿⠿⠶⠙⣿⡟⠡⣴⣿⣽⣿⣧ ⢸⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⣾⣿⣿⣟⣭⣾⣿⣷⣶⣶⣴⣶⣿⣿⢄⣿⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⣿⣿⣿⡟⣩⣿⣿⣿⡏⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⣿⣹⡋⠘⠷⣦⣀⣠⡶⠁⠈⠁⠄⣿⣿⣿⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⣿⣍⠃⣴⣶⡔⠒⠄⣠⢀   ⡨⣿⣿⣿⣿⣿⣿
	⣿⣿⣿⣿⣿⣿⣿⣦⡘⠿⣷⣿⠿⠟⠃  ⣠⡇⠈⠻⣿⣿⣿⣿
	⣿⣿⣿⣿⡿⠟⠋⢁⣷⣠    ⣀⣠⣾⡟    ⠉⠙⠻
	⡿⠟⠋⠁   ⢸⣿⣿⡯⢓⣴⣾⣿⣿⡟        
	       ⣿⡟⣷⠄⠹⣿⣿⣿⡿⠁        
";

sub loader {
  $bot->add_handler("chancmd glorytoccp", "ccp");
}

sub ccp {
  my ($nick, $host, $chan, $text) = @_;

  print "summoning our leader\n";
  my @leaderSplit = split(/\n/, $leader);
  foreach my $l (@leaderSplit) {
    
    if (defined &Lolcat::lolcat) {
      Lolcat::lolcat($nick, $host, $chan, $l);
    } else {
      $bot->say($chan, $l);
    }
  }
}

sub unloader {
  $bot->del_handler("chancmd glorytoccp", "ccp");
}

1;
