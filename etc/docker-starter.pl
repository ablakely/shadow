#!/usr/bin/perl -w

use strict;
use warnings;

while (1) {
    system "STARTER_PID=$$ /opt/shadow/shadow -n -v"
}