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

# Core Dependencies
push(@dependsRaw, "JSON");
push(@dependsRaw, "Digest::SHA");

# OS-specific for BotStats
if ($^O eq "msys" || $^O eq "MSWin32") {
  push(@dependsRaw, "Win32::OLE");
} elsif ($^O eq "linux") {
  push(@dependsRaw, "Proc::ProcessTable");
} else {
  print "[Warning] BotStats module only supports Windows or Linux, it will not be available on this install.\n";
}

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
				print " -- Found $pkg in $file, adding to install list.\n";
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

print "\nDone.  Your enviornment is now prepared for shadow.\n";
print "Make sure you edit etc/shadow.conf then run ./shadow\n";
my $whome = `whoami`;
chomp $whome;
print "Party on, ".$whome."!\n";
