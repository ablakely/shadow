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
	$self->{confFile} = $confFile;

	push @confFiles, $confFile;

	return bless($self, $class);
}

sub parse {
	my $self = shift;
	my %c	  = ();
	my $cur	  = "";
	my $curr  = "";
	my @tmp;
	my $lc    = 0;
	my $i     = 0;

	foreach my $f (@confFiles) {
		open (FH, "<$f") or die $!;
		while(<FH>) {
			if (/^\#(.*)/) {
				$lc++;
				next;
			}
			elsif (/^\s/ || /^\r/ || /^\n/) {
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
				@tmp = split(/\,/, $3);

				for ($i = 0; $i < scalar(@tmp); $i++) {
					$c{$cur}->{$curr}->{$1}->{$2}[$i] = $tmp[$i];
				}

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
				print "[".$self->{confFile}.":$lc] Invalid statement:".$_."\n";
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
