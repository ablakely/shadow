# Shadow::Config	- Configuration Module Parser
# Written by Aaron Blakely <aaron@ephasic.org>
#
# Copyright 2012 (C) Aaron Blakely

package Shadow::Config;

use strict;
use warnings;

our $VERSION = "0.1";
our @confFiles;

sub new {
	my $class = shift;
	my ($confFile) = @_;

	my $self = { };

	push @confFiles, $confFile;

	return bless($self, $class);
}

sub parse {
	my $class = shift;
	my %c	  = ();
	my $cur	  = "";
	my $curr  = "";

	foreach my $f (@confFiles) {
		open (FH, "<$f") or die $!;
		while(<FH>) {
			if (/^\#(.*)/) {
				next;
			}
			elsif (/^\!(.*)$/) {
				#$c{$cur} = ();
				$cur = $1;
				next;
			}
			elsif (/^\_(\w+)\_$/) {
				#$c{$cur}->{$1} = ();
				$curr = $1;
				next;
			}
			elsif (/^(\w+)\.(\w+)\s*\=\s*(.*)$/) {
				$c{$cur}->{$curr}->{$1}->{$2} = $3;
				next;
			}
			elsif (/^(\w+)\.(\w+)\[(\d+)\]\s*\=\s*(.*)$/) {
				$c{$cur}->{$curr}->{$1}->{$2}[$3] = $4;
				next;
			}
		}

		close FH or die $!;
	}

	return \%c;
}

sub add { my $class = shift; push @confFiles, shift; return 1; };
sub rehash { return parse(); };

1;
