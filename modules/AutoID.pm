package AutoID;

# AutoID Module for Shadow.
#
# Compatibilty:
#

my $pwfile = "./etc/autoid.pd";
my $bot    = Shadow::Core;
my $help   = Shadow::Help;

sub loader {
  $bot->add_handler('event connected', 'autoid_connected');
  $bot->add_handler('privcmd nsregister', 'autoid_register');
  $bot->add_handler('privcmd nspasswd', 'autoid_passwd');

  $help->add_help('nsregister', 'AutoID', '<nickserv> <email> <password>', 'Register bot with NickServ.', 1);
  $help->add_help('nspasswd', 'AutoID', '', 'Prints current NickServ password.', 1);
}

sub genpw {
    my $maxchars = 20;
    my @letters = (
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
        'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        'W', 'Z', 'Y', 'Z'
    );

    $maxchars = $maxchars / 2;

    my $alisas;
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
    open(my $f, "<", $pwfile) or return $bot->err("AutoID Error: ".$!, 0);
    $nspasswd = <$f>;
    close($f) or $bot->err("AutoID Error: ".$!, 0);

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
    open(my $f, ">", $pwfile) or return $bot->err("AutoID Error: ".$!, 0);
    print $f "$ns:$pw\n";
    close($f) or $bot->err("AutoID Error: ".$!, 0);

    $bot->say($ns, "REGISTER $pw $email");
    $bot->notice($nick, "Registered with NickServ: $email $pw");
  }
}

sub autoid_passwd {
  my ($nick, $host) = @_;

  if ($bot->isbotadmin($nick, $host)) {
    open(my $x, "<", $pwfile) or return $bot->err("AutoID Error: ".$!, 0);
    my $f = <$x>;
    close($x) or $bot->err("AutoID Error: ".$!, 0);
    chomp $f;

    my ($s, $pw) = split(/:/, $pw);

    $bot->notice($nick, "$s password: $pw");
  } else {
    $bot->notice($nick, "Unauthorized.");
  }
}

sub unloader {
  $bot->del_handler('event connected', 'autoid_connected');
  $bot->del_handler('privcmd nsregister', 'autoid_register');
  $bot->del_handler('privcmd nspasswd', 'autoid_passwd');

  $bot->del_help('nsregister', 'AutoID');
  $bot->del_help('nspasswd', 'AutoID');
}

1;
