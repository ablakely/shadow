#!/usr/bin/perl -w
#
# shadow install script
# Written by Aaron Blakely
#
#

use strict;
use warnings;
use CPAN;

my @dependsRaw;
my @depends;

sub sortArray {
	my %seen;
	grep !$seen{$_}++, @_;
}

# Get a dir listing
opendir(MODS, "./modules") or die $!;
while (my $file = readdir(MODS)) {
	if ($file =~ /\.pm/) {
		open(MODFILE, "<./modules/$file") or die $!;

		while (my $line = <MODFILE>) {
			if ($line =~ /use (.*);/) {
				my ($pkg, $arg) = split(/ /, $1);
				push(@dependsRaw, $pkg) if $pkg ne "open";
			}

		}

		close(MODFILE);
	}
}
closedir(MODS);

@depends = sortArray(@dependsRaw);

foreach my $mod (@depends) {
	print "Checking for $mod...";
	eval "require $mod";

	if ($@) {
		print "Not found.\nInstalling...\n";
		install($mod);
	} else {
		print "Excellent!\n";
	}
}

print "\nDone.  You're enviornment is now prepared for shadow.\n";
print "Make sure you edit etc/shadow.conf then run ./shadow\n";
my $whome = `whoami`;
chomp $whome;
print "Party on, ".$whome."!\n";
