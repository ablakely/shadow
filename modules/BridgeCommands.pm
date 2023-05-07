package BridgeCommands;

# BridgeCommands - Allows users of a protocol bridge (such as Discord or Minecraft to IRC bridges)
#
# Bridge Output format: [world] <$nick> $msg
#
# Written by Aaron Blakely

####### CONFIG ########
my $bridgeBotName = "EphasicMC";
my $bridgeChannel = "#minecraft";
####### /CONFIG #######


my $bot = Shadow::Core;


sub loader {
  $bot->register("BridgeCommands", "v0.5", "Aaron Blakely");
  $bot->add_handler("message channel", "msgHandler");
}

sub msgHandler {
  my ($nick, $host, $chan, $text)  = @_;
  my @tmp;

  if ($nick eq $bridgeBotName && $chan eq $bridgeChannel) {
    if ($text =~ /^\[(.*)\] \<(.*)\> (.*)/) {
      $nick = $2;
      my $cmd = $3;
      $cmd =~ s/^\s+//;
      $cmd =~ s/^\Q$Shadow::Core::options{irc}->{cmdprefix}\E//;

      @tmp = split(" ", $cmd);

      Shadow::Core::handle_handler('chancmd', $tmp[0], $nick, $host, $chan, $tmp[1]);
    }
  }
}

sub unloader {
  $bot->unregister("BridgeCommands");
  $bot->del_handler("message channel", "msgHandler");
}

1;
