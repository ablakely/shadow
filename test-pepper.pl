#!/usr/bin/perl -w


#$INDEP[Tcl]

use lib './modules/Pepper';
use strict;
use warnings;

use Pepper;

my $pepper = Pepper->new();

#my $res = $pepper->exec('puts "Henlo from TCL"');
my $res = $pepper->eval('bind pubm -|- !hello greet_user');

print "Error: ".$res->{err}."\n" if (exists($res->{err}));

print "here\n";

