package Shadow::Formater;

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

sub render {
    my $self = shift;
    my $tab = "    ";

    my @colspacing;
    my @ret;

    for (my $i = 0; $i < scalar(@{$self->{header}}); $i++) {
        # find the length of each header col text
        push(@colspacing, length($self->{header}[$i]));
    }

    for (my $i = 0; $i < scalar(@{$self->{body}}); $i++) {
        for (my $x = 0; $x < scalar(@{$self->{body}[$i]}); $x++) {
            
            # increment spacing for larger column cells in body
            $colspacing[$x] = length($self->{body}[$i][$x]) > length($colspacing[$x]) ? length($self->{body}[$i][$x]) : $colspacing[$x];
        }
    }

    my $i = 0;
    my $headerstr = "| ";
    foreach my $cval (@{$self->{header}}) {
        my $spacing = $colspacing[$i] - length $cval > 0 ? $colspacing[$i] - length $cval : $colspacing[$i];
        $spacing    = " "x$spacing;

        $headerstr .= "$cval$spacing | ";

        $i++;
    }
    
    #print "dbug: $headerstr\n";
    my $bar = "-" x (length($headerstr) - 1);

    push(@ret, $headerstr);
    push(@ret, $bar);

    my $rowstr = "| ";
    for (my $row = 0; $row < scalar(@{$self->{body}}); $row++) {
        for (my $col = 0; $col < scalar(@{$self->{body}[$row]}); $col++) {
            my $cval = $self->{body}[$row][$col];

            my $spacing = $colspacing[$row] - length $cval;
            print "dbug: spacing $colspacing[$row] - ".length($cval)." = $spacing\n";

            if ($spacing > 0) {
                $spacing    = " "x$spacing;

                $rowstr .= "$cval$spacing | ";
            } else {
                $rowstr .= "$cval | ";
            }
        }

        push(@ret, $rowstr);
        $rowstr = "| ";
    }

    push(@ret, $bar);

    return @ret;

}


# | Feed      | URL                               | Sync Time     | Format                      | 
# -----------------------------------------------------------------------------------------------
# | r/Memphis | https://reddit.com/r/memphis/.rss | 2330          | [r/Memphis] %TITLE% [%URL%] | 



1;