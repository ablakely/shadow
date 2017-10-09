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

foreach my $mod (@{$Shadow::Core::options{cfg}->{Shadow}->{Bot}->{system}->{modules}}) {
  $bot->load_module($mod);
}

# Start the wheel...
$bot->connect();
