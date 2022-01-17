package Neofetch;

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
    $bot->add_handler('chancmd neofetch', 'doNeoFetch');
    $bot->add_handler('chancmd sysinfo', 'doNeoFetch');
}

sub doNeoFetch {
    my ($nick, $host, $chan, $text) = @_;

    my @neofetch = `neofetch --off --distro_shorthand tiny --color_blocks off --underline off|sed 's/\x1B\[[0-9;\?]*[a-zA-Z]//g'`;

    for (my $i = 0; $i < $#neofetch; $i++) {
        chomp $neofetch[$i];

        if ($neofetch[$i] =~ /(.*)\: /) {
            my $t = $1;
            $neofetch[$i] =~ s/$t/\002$t\002/;
        }
    }

    for (my $i = 0; $i < $#neofetch; ) {
        if ($i == 0) {
            $neofetch[$i] = $bot->bold()."Host: ".$bot->bold().$neofetch[$i];
        }

        $bot->say($chan, "$neofetch[$i] $neofetch[$i+1] $neofetch[$i+2] $neofetch[$i+3] $neofetch[$i+4]");
        $i = $i+5;
    }
}

sub unloader {
    $bot->del_handler('chancmd neofetch', 'doNeoFetch');
    $bot->del_handler('chancmd sysinfo', 'doNeoFetch');
}

1;