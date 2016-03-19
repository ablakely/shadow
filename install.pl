#!/usr/bin/perl -w
#
# shadow install script
# Written by Aaron Blakely
#
#

use strict;
use warnings;
use CPAN;

print "Checking for Mojo::UserAgent...\t\t";
eval ("require Mojo::UserAgent;");
if ($@) {
	print "Not found.\nInstalling...\n";
	install("Mojo::UserAgent;");
} else {
	print "Excellent!\n";
}

print "Checking for JSON...\t\t\t\t";
eval ("require JSON;");
if ($@) {
	print "Not found.\nInstalling...\n";
	install("JSON")
} else {
	print "Excellent!\n";
}

print "Checking for Sub::Delete...\t\t\t";
eval ("require Sub::Delete;");
if ($@) {
	print "Not found.\nInstalling...\n";
	install("Sub::Delete");
} else {
	print "Excellent!\n";
}

print "\nDone.  You're enviornment is now prepared for shadow.\n";
print "Make sure you edit etc/shadow.conf then run bin/shadow.pl\n";
my $whome = `whoami`;
chomp $whome;
print "Party on, ".$whome."!\n";
