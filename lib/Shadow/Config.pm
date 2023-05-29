# Shadow::Config	- Configuration Parser Module
# Written by Aaron Blakely <aaron@ephasic.org>
#
# Copyright 2012 (C) Aaron Blakely

package Shadow::Config;

use strict;
use warnings;

our $VERSION = "0.6";
our @confFiles;

sub new {
    my $class = shift;
    my ($confFile) = @_;

    my $self = { };
    $self->{confFile} = $confFile;

    push @confFiles, $confFile;

    return bless($self, $class);
}

sub parse {
    my $self = shift;
    my %c	  = ();
    my $cur	  = "";
    my $curr  = "";
    my (@lines, @tmp);
    my $lc    = 0;
    my $i     = 0;
    my $slurp = 0;
    my ($s1, $s2);

    foreach my $f (@confFiles) {
        open (FH, "<$f") or die $!;
        while(<FH>) {
            s/\r\n/\n/gs;

            if (/^\#(.*)/) {
                $lc++;
                next;
            }
            elsif (/^\r/ || /^\n/ || /^\r\n/) {
                $lc++;
                next;
            }
            elsif (/^\@(.*)$/) {
                $lc++;
                $cur = $1;
                next;
            }
            elsif (/^\[(\w+)\]$/) {
                $lc++;
                $curr = $1;
                next;
            }
            elsif (/^(\w+)\.(\w+)\s*\=\s*\"(.*)\"$/ || /^(\w+)\.(\w+)\s*\=\s*\'(.*)\'$/) {
                $lc++;
                $c{$cur}->{$curr}->{$1}->{$2} = $3;
                next;
            }
            elsif (/^(\w+)\.(\w+)\s*\=\s*\[(.*)\]$/) {
                $lc++;
                @tmp = split(/\,[\s]?/, $3);

                for ($i = 0; $i < scalar(@tmp); $i++) {
                    $c{$cur}->{$curr}->{$1}->{$2}[$i] = $tmp[$i];
                }

                next;
            }
            elsif (/^(\w+)\.(\w+)\s*\=\s*\[$/) {
                    $slurp = 1;
                    $s1 = $1;
                    $s2 = $2;

                    $lc++;
                    next;
                }
                elsif (/^]$/) {
                $slurp = 0;
                $lc++;

                for ($i = 0; $i < scalar(@lines); $i++) {
                    $c{$cur}->{$curr}->{$s1}->{$s2}[$i] = $lines[$i];
                }
                
                @lines = ();

                next;
            }
            elsif (/^(\w+)\.(\w+)\s*\=\s*yes$/) {
                $lc++;
                $c{$cur}->{$curr}->{$1}->{$2} = 1;
                next;
            }
            elsif (/^(\w+)\.(\w+)\s*\=\s*no$/) {
                $lc++;
                $c{$cur}->{$curr}->{$1}->{$2} = 0;
            }
            else {
                chomp;
                if ($slurp) {
                    $_ =~ s/\s+(.*)[\,?]/$1/g;
                    $_ =~ s/\s+(.*)/$1/g;

                    push(@lines, $_);

                    $lc++;
                    next;
                } else {
                    print "[".$self->{confFile}.":$lc] Invalid statement:".$_."\n";
                }
            }
            $lc++;
        }

        close FH or die $!;
    }

    return \%c;
}

sub add { my $class = shift; push @confFiles, shift; return 1; };
sub rehash { return parse(); };

1;
