package Chan5000;

my $bot = Shadow::Core;
my $help = Shadow::Help;

my %users;
my $unload = 0;

sub loader {
    $bot->join('#5000');
    $bot->add_handler('event join', 'join5000');
    $bot->add_handler('event quit', 'quit5000');
    $bot->add_timeout(20, 'check5000');
}

sub genchan {
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

    return "#".$alias;
}

sub join5000 {
    my ($nick, $host, $channel) = @_;

    return unless $channel eq '#5000';
    return if $nick eq $bot->nick;

    $users{$nick} = {
        'action' => 'JOIN'
    };

    $bot->say($channel, "Welcome to #5000, $nick!");
    $bot->say("#lobby", "RIP $nick");
}

sub quit5000 {
    my ($nick, $host, $reason) = @_;

    return unless exists $users{$nick};
    return if $users{$nick}->{'quit'};

    $users{$nick}->{'action'} = 'QUIT';

    $bot->say('#5000', "Goodbye, $nick!");
}

sub check5000 {
    return if $unload;

    foreach my $user (keys %users) {
        if ($users{$user}->{'action'} eq 'JOIN') {
            $users{$user}->{'action'} = 'PART';

            for (my $i = 0; $i < 40; $i++) {
                my $chan = genchan();
                $bot->fastout("SAJOIN $user :$chan\r\n");

                @{$users{$user}->{'fchans'}} = () unless exists $users{$user}->{'fchans'};
                push(@{$users{$user}->{'fchans'}}, $chan);
            }
        } elsif ($users{$user}->{'action'} eq 'PART') {
            $users{$user}->{'action'} = 'JOIN';

            foreach my $chan (@{$users{$user}->{'fchans'}}) {
                $bot->fastout("SAPART $user :$chan\r\n");
            }
        } elsif ($users{$user}->{'action'} eq 'QUIT') {
            delete $users{$user};
        }
    }

    $bot->add_timeout(20, 'check5000');
}


sub unloader {
    $bot->del_handler('event join', 'join5000');
    $bot->del_handler('event quit', 'quit5000');
    $unload = 1;
}


1;
