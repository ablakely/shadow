use strict;
use warnings;
use Data::Dumper;
use lib "./lib";
use Shadow::Config;

my $parser = Shadow::Config->new("./etc/shadow.conf", 0);
my $cfg = $parser->parse();

print Dumper($cfg);
