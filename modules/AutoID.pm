package AutoID;

# AutoID Module for Shadow.
#
# Compatibilty:
#

my $pwfile = "./etc/autoid.pd";
my $bot    = Shadow::Core;
my $help   = Shadow::Help;

sub loader {
  $bot->register("AutoID", "v1.0", "Aaron Blakely");

  $bot->add_handler('event connected', 'autoid_connected');
  $bot->add_handler('privcmd nsregister', 'autoid_register');
  $bot->add_handler('privcmd nspasswd', 'autoid_passwd');
  $bot->add_handler('event nicktaken', 'autoid_ghost');
  $bot->add_handler('privcmd nsverify', 'autoid_verify');

  $help->add_help('nsregister', 'AutoID', '<nickserv> <email> <password>', 'Register bot with NickServ.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02NSREGISTER\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "nsregister will register the bot with NickServ.");
    $bot->say($nick, "If no password is given then the bot will generate it's own password.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick nsregister <nickserv> <email> <password>");
  });
  $help->add_help('nspasswd', 'AutoID', '', 'Prints current NickServ password.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02NSPASSWD\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "nspasswd will return the current password used for identifying with nickserv.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick nspasswd");
  });

  $help->add_help('nsverify', 'AutoID', '<nickserv> <verication code>', 'For networks that use 2FA email varification.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02NSVERIFY\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "nsverify is used for networks like Freenode which require its users to verify their email.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick nsverify <nickserv> <verification code>");
  });
}

sub genpw {
    my $maxchars = 20;
    my @letters = (
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
        'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        'W', 'Z', 'Y', 'Z'
    );

    $maxchars = $maxchars / 2;

    my $alias;
    my ($x, $y);

    for (my $i = 0; $i < $maxchars; $i++) {
        $x = int(rand($#letters));
        $y = int(rand(9));

        if ($x % 2) {
            $alias .= lc($letters[$x]);
        } else {
            $alias .= $letters[$x];
        }

        $alias .= $y;
    }

    return $alias;
}

sub autoid_connected {
  if (-e $pwfile) {
    open(my $f, "<", $pwfile) or return $bot->err("AutoID Error: $!", 0, "Modules");
    my $nspasswd = <$f>;
    close($f) or $bot->err("AutoID Error: ".$!, 0, "Modules");

    chomp $nspasswd;
    my ($ns, $pw) = split(/\:/, $nspasswd);

    $bot->say($ns, "identify $pw");
  }
}

sub autoid_register {
  my ($nick, $host, $text) = @_;
  my ($ns, $email, $pw) = split(/ /, $text);
  $pw = genpw() if !$pw;

  return $bot->notice($nick, "Syntax: /msg $Shadow::Core::nick nsregister <nickserv> <email> [password]") if !$ns;

  if ($bot->isbotadmin($nick, $host)) {
    open(my $f, ">", $pwfile) or return $bot->err("AutoID Error: ".$!, 0, "Modules");
    print $f "$ns:$pw\n";
    close($f) or $bot->err("AutoID Error: ".$!, 0, "Modules");

    $bot->say($ns, "REGISTER $pw $email");
    $bot->notice($nick, "Registered with NickServ: $email $pw");
  }
}

sub autoid_passwd {
  my ($nick, $host) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    open(my $x, "<", $pwfile) or return $bot->err("AutoID Error: ".$!, 0, "Modules");
    my $f = <$x>;
    close($x) or $bot->err("AutoID Error: ".$!, 0, "Modules");
    chomp $f;

    my ($s, $pw) = split(/\:/, $f);

    $bot->notice($nick, "$s password: $pw");
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub autoid_ghost {
  my ($taken, $tmpnick) = @_;
  $bot->log("AutoID: Ghosting $taken", "Modules");

  open(my $f, "<", $pwfile) or return $bot->err("AutoID Error: ".$!, 0, "Modules");
  my $c = <$f>;
  close($f);
  chomp $c;

  my ($ns, $pw) = split(/\:/, $c);

  $bot->raw("PRIVMSG $ns :GHOST $taken $pw");
  $bot->nick($taken);
}

sub autoid_verify {
  my ($nick, $host, $text) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    my ($ns, $str) = split(/ /, $text);

    $bot->say($ns, "VERIFY REGISTER $Shadow::Core::nick $str");
  }
}

sub unloader {
  $bot->unregister("AutoID");
  $bot->del_handler('event connected', 'autoid_connected');
  $bot->del_handler('privcmd nsregister', 'autoid_register');
  $bot->del_handler('privcmd nspasswd', 'autoid_passwd');
  $bot->del_handler('event nicktaken', 'autoid_ghost');
  $bot->del_handler('privcmd nsverify', 'autoid_verify');

  $help->del_help('nsregister', 'AutoID');
  $help->del_help('nspasswd', 'AutoID');
  $help->del_help('nsverify', 'AutoID');
}

1;
