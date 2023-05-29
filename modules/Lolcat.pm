package Lolcat;

use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
    $bot->register("Lolcat", "v1.0", "Aaron Blakely", "lolcat for IRC");
    $bot->add_handler('chancmd lolcat', 'lolcat_cmd');
}

sub fastcat {
    my ($target, @text) = @_;

    my $lines = join("\n", @text);
    my @out = lolcat($lines);

    $bot->fastsay($target, @out);
}

sub lolcat {
    my ($nick, $host, $chan, $text) = @_;
    
    my $retmode = 0;

    if (scalar(@_) < 3) {
        $retmode = 1;
        $text = $nick;
    }

    my @textSplit = split(//, $text); 
    my @lines;

    my $min = 3;
    my $max = 12;
    my $lc  = 0;
    my $reverse = 0;

    # use $cnt to iterate through color code range from $min and $max

    my $cnt = $min + int(rand($max - $min)) + 1;
    foreach my $char (@textSplit) {
        if ($char eq " ") { $lines[$lc] .= " "; next; }
        if ($char eq "\n") { $lines[$lc] .= "\x03"; $lc++; next;}

        if ($cnt > $max) {
            $reverse = 1;
        }

        if ($cnt < $min) {
            $reverse = 0;
        }

        if ($reverse) {
            $cnt--;
        } else {
            $cnt++;
        }

        $lines[$lc] .= $cnt < 10 ? "\x030$cnt\x02$char\x02" : "\x03$cnt\x02$char\x02";
    }


    if (!$retmode) {
        $bot->fastsay($chan, @lines);
    } else {
        return @lines;
    }
}

sub unloader {
    $bot->unregister("Lolcat");
    $bot->del_handler('chancmd lolcat', 'lolcat');
}
