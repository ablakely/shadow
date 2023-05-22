#!/usr/bin/perl -w


use lib './lib';
use utf8;
use strict;
use warnings;
use Shadow::Formatter;

# utf8 out
binmode(STDOUT, "encoding(UTF-8)");

my $fmt = Shadow::Formatter->new();

#$fmt->table_header("Feed", "URL", "Inverval", "Format");
#$fmt->table_row("r/Memphis", "https://reddit.com/r/memphis/.rss", "2330 seconds", "[r/Memphis] \%TITLE\% [\%URL\%]");
#$fmt->table_row("\@ziptiesnbiasplies", "https://youtube.com/feeds/ziptiesnbiasplies/rss", "250 seconds", "Mint !!!!!!! \%TITLE\% [\%URL\%]");

$fmt->table_header("Hook", "Count");

$fmt->table_row("chancmd *"      , "\x030322 \x02handlers\x02\x03");
$fmt->table_row("event nicktaken", "1 handlers");
$fmt->table_row("message channel", "1 handlers");
$fmt->table_row("event connected", "\x037REEE DIT\x03 \x02%TITLE%\x02 [%URL%]");
$fmt->table_row("event tick"     , "2 👌🌎 handlers");
$fmt->table_row("privcmd *"   , "26 handlers");

foreach my $line ($fmt->table()) {
    print "$line\n";
}
