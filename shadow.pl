#!/usr/bin/perl -w

# shadow: Perl IRC Bot
#
# Written by Aaron Blakely

use lib './lib';
use strict;
use warnings;
use Shadow::Core;
use Shadow::Config;

$| = 1;

my $configfile		= $ARGV[0] || './etc/shadow.conf';

my $bot = Shadow::Core->new($configfile, 1);

$bot->load_module("ChanOP");
$bot->load_module("AutoID");

# Start the wheel...
$bot->connect();
