package Neofetch;

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
    $bot->add_handler('chancmd neofetch', 'doNeoFetch');
    $bot->add_handler('chancmd sysinfo', 'doNeoFetch');
}

sub doNeoFetch {
    my ($nick, $host, $chan, $text) = @_;
    my $osColor = $bot->color('white');

    my @neofetch = `neofetch --off --title_fqdn on --cpu_temp F --distro_shorthand tiny --color_blocks off --memory_percent on --underline off|sed 's/\x1B\[[0-9;\?]*[a-zA-Z]//g'`;

    for (my $i = 0; $i < $#neofetch; $i++) {
        chomp $neofetch[$i];
        $neofetch[$i] =~ s/\N{U+00C2}//g;
        

        if ($neofetch[$i] =~ /(.*)\: (.*)/) {
            my $t = $1;

            if ($t eq "OS") {
                if ($2 =~ /Debian/) {    $osColor = $bot->color('lightred'); }
                elsif ($2 =~ /Arch/) {   $osColor = $bot->color('lightcyan'); }
                elsif ($2 =~ /Ubuntu/) { $osColor = $bot->color('orange'); }
                elsif ($2 =~ /Linux Mint/) { $osColor = $bot->color('lightgreen'); }
            }

            $neofetch[$i] =~ s/$t/\002$osColor$t\003\002/;
        }
    }

    for (my $i = 0; $i < $#neofetch; ) {
        if ($i == 0) {
            	$neofetch[$i] =~ s/^(.*)\@//g;
		$neofetch[$i] = $bot->bold().$osColor."Hostname\003".$bot->bold().": ".$neofetch[$i];
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
