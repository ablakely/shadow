#!/usr/bin/perl -w
# Uptime Module: Pre-install Script
# Written by Dark_Aaron
#

use strict;
use warnings;

# Check to see that we have uptime
my $uptime_exec = `which uptime`;
chomp $uptime_exec;

if (-e $uptime_exec) {
	exit;
} else {
	die;
}
