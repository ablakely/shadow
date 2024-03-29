package Neofetch;

use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
    $bot->register("Neofetch", "v2.0", "Aaron Blakely", "System information using neofetch");

    $bot->add_handler('chancmd neofetch', 'doNeoFetch');
    $bot->add_handler('chancmd sysinfo', 'doNeoFetch');
}

sub doNeoFetch {
    my ($nick, $host, $chan, $text) = @_;
    my @out;

    my $osColor = $bot->color('white');

    my $neofetchBin = "neofetch";

    if ($^O =~ /msys/ || $^O =~ /MSWin32/) {
        $neofetchBin = "sh neofetch --shell_version off";
    }

    my @neofetch = `$neofetchBin --off --title_fqdn on --cpu_temp F --distro_shorthand tiny --color_blocks off --memory_percent on --underline off|sed 's/\x1B\[[0-9;\?]*[a-zA-Z]//g'`;

    for (my $i = 0; $i < $#neofetch; $i++) {
        chomp $neofetch[$i];
        $neofetch[$i] =~ s/\N{U+00C2}//g;
        

        if ($neofetch[$i] =~ /(.*)\: (.*)/) {
            my $t = $1;

            if ($t eq "OS") {
                if ($2 =~ /Debian/ || $2 =~ /Raspbian/ || $2 =~ /Red Hat Enterprise Linux/) { $osColor = $bot->color('lightred'); }
                elsif ($2 =~ /Arch/ || $2 =~ /elementary OS/ || $2 =~ /Windows/) { $osColor = $bot->color('lightcyan'); }
                elsif ($2 =~ /Ubuntu/) { $osColor = $bot->color('orange'); }
                elsif ($2 =~ /Linux Mint/ || $2 =~ /Manjaro/) { $osColor = $bot->color('lightgreen'); }
                elsif ($2 =~ /Gentoo/) { $osColor = $bot->color('purple'); }
                elsif ($2 =~ /Fedora/) { $osColor = $bot->color('lightblue'); }
                elsif ($2 =~ /Pop\!_OS/) { $osColor = $bot->color('cyan'); }
            }

            $neofetch[$i] =~ s/$t/\002$osColor$t\003\002/;
        }
    }

    for (my $i = 0; $i < $#neofetch; ) {
        if ($i == 0) {
            if ($^O !~ /msys/ && $^O !~ /MSWin32/) {
                $neofetch[$i] =~ s/^(.*)\@//g;
		        $neofetch[$i] = $bot->bold().$osColor."Hostname\003".$bot->bold().": ".$neofetch[$i];
            } else {
                splice(@neofetch, 0, 1);
            }
        }

        push(@out, "$neofetch[$i] $neofetch[$i+1] $neofetch[$i+2] $neofetch[$i+3] $neofetch[$i+4]");
        $i = $i+5;
    }

    $bot->fastsay($chan, @out);
}

sub unloader {
    $bot->unregister("Neofetch");
    
    $bot->del_handler('chancmd neofetch', 'doNeoFetch');
    $bot->del_handler('chancmd sysinfo', 'doNeoFetch');
}

1;
