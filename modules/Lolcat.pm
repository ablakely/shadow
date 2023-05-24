package Lolcat;

use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
    $bot->register("Lolcat", "v1.0", "Aaron Blakely");
    $bot->add_handler('chancmd lolcat', 'lolcat');
}

sub lolcat {
    my ($nick, $host, $chan, $text) = @_;

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


    foreach my $str (@lines) {
        $bot->say($chan, $str);
    }
}

sub unloader {
    $bot->unregister("Lolcat");
    $bot->del_handler('chancmd lolcat', 'lolcat');
}
