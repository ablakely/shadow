use Data::Dumper;

sub sortTimeStampArray {
    my (@arr) = @_;
    my (@AM, @PM, @AMR, @PMR);

    foreach my $v (@arr) {
        if ($v =~ /AM/) {
            push(@AM, $v);
        } elsif ($v =~ /PM/) {
            push(@PM, $v);
        }
    }

    @AM = sort(@AM);
    @PM = sort(@PM);

    foreach my $v (@AM) {
        if ($v =~ /12/) {
            unshift(@AMR, $v);
        } else {
            push(@AMR, $v);
        }
    }
    
    foreach my $v (@PM) {
        if ($v =~ /12/) {
            unshift(@PMR, $v);
        } else {
            push(@PMR, $v);
        }
    }

    my @ret = (@AMR, @PMR);

    return @ret;
}

print Dumper(sortTimeStampArray("01 AM", "02 AM", "03 AM", "12 AM"));
