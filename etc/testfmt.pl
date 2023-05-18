use lib './lib';
use strict;
use warnings;
use Shadow::Formater;

my $fmt = Shadow::Formater->new();

$fmt->table_header("Feed", "URL", "SYNCTIME", "Format");

$fmt->table_row("r/Memphis", "https://reddit.com/r/memphis/.rss", "2330 seconds", "[r/Memphis] \%TITLE\% [\%URL\%]");
$fmt->table_row("\@ziptiesnbiasplies", "https://youtube.com/feeds/ziptiesnbiasplies/rss", "250 seconds", "Mint !!!!!!! \%TITLE\% [\%URL\%]");

foreach my $line ($fmt->render()) {
    print "$line\n";
}