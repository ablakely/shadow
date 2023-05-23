package Shadow::Formatter;

# Shadow::Formatter - Generates ASCII tables and other text formatting sutible for IRC.
#
# Written by Aaron Blakely <aaron@ephasic.org>
#

use utf8;
use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;

    my $self = {
        header => (),
        body   => ()
    };

    return bless($self, $class);
}

sub table_header {
    my ($self, @cols) = @_;

    $self->{header} = \@cols;
}

sub table_row {
    my ($self, @cols) = @_;

    push(@{$self->{body}}, \@cols);
}

sub count_emojis {
    my ($string) = @_;
    my $count = () = $string =~ /[\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}]/gu;
    return $count;
}

sub len {
    my $str = shift;
    my $ret = length($str);
    my $colorctrl_cnt = 0;
    my $boldctrl_cnt  = 0;

    if ($str =~ /\x03(\d{1,2}\,\d{1,2}|\d{1,2})?/g) {
        if ($1) {
            $colorctrl_cnt += length($1);
        }

        $colorctrl_cnt += scalar(split("\x03", $str));
    }

    if ($str =~ /\x02/g) {
        $boldctrl_cnt  += () = $str =~ /\x02/g;
    }
    
    $ret += count_emojis($str);
    $ret += $boldctrl_cnt;
    $ret += $colorctrl_cnt;
    return $ret;
}

sub table {
    my $self = shift;
    my $tab = "    ";

    my @colspacing;
    my @ret;

    for (my $i = 0; $i < scalar(@{$self->{header}}); $i++) {
        # find the length of each header col text
        push(@colspacing, len($self->{header}[$i]));
    }

    for (my $i = 0; $i < scalar(@{$self->{body}}); $i++) {
        for (my $x = 0; $x < scalar(@{$self->{body}[$i]}); $x++) {
            
            # increment spacing for larger column cells in body
            $colspacing[$x] = len($self->{body}[$i][$x]) > $colspacing[$x] ? len($self->{body}[$i][$x]) : $colspacing[$x];

        }
    }

    my $i = 0;
    my $headerstr = "| ";
    foreach my $cval (@{$self->{header}}) {
        my $spacing = $colspacing[$i] - len($cval) > 0 ? $colspacing[$i] - len($cval) : $colspacing[$i];
        $spacing    = " "x$spacing;

        $headerstr .= ($i + 1) < scalar(@{$self->{header}}) ? "$cval$spacing | " : "$cval$spacing ";

        $i++;
    }

    my $bar = "-" x len($headerstr);

    push(@ret, $headerstr);
    push(@ret, $bar);

    my $rowstr = "| ";
    for (my $row = 0; $row < scalar(@{$self->{body}}); $row++) {
        for (my $col = 0; $col < scalar(@{$self->{body}[$row]}); $col++) {
            my $cval = $self->{body}[$row][$col];
            my $ccnt = 0;

            my $spacing = $colspacing[$col] - length($cval);
            $ccnt += () = $cval =~ /\x03/g;
            $ccnt += () = $cval =~ /\x02/g;

            my $ecnt = count_emojis($cval);

            if ($ecnt > 0) {
                $ccnt += -1 * $ecnt;
            }
            

            $spacing += $ccnt;
            my $headerlen = len($self->{header}[$col]);

            if ($headerlen > len($cval)) {
                if (($headerlen + $spacing) > $colspacing[$col]) { 
                    $spacing = (len($cval) + $headerlen) > $colspacing[$col] ? $headerlen+$spacing : $spacing;
                }
            }

            if ($spacing > 0) {
                $spacing    = " "x($spacing);

                $rowstr .= ($col + 1) < scalar(@{$self->{body}[$row]}) ? "$cval$spacing | " : "$cval$spacing ";
            } else {
                $rowstr .=  ($col + 1) < scalar(@{$self->{body}[$row]}) ? "$cval | " : "$cval ";
            }
        }

        push(@ret, $rowstr);
        $rowstr = "| ";
    }

    push(@ret, $bar);
    return @ret;

}

1;
