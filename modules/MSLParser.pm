package MSLParser;

# MSLParser.pm - Shadow module for mIRC Scripting Language scripts
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright (C) 2022 Ephasic Software


my $bot = Shadow::Core;

my %mslevents;
my %mslvars;
my %mslfunctions;

sub loader {
    initmsl_builtin();

    $bot->add_handler('ctcp action', 'mslevent_action');
    $bot->add_handler('event nick', 'mslevent_nick');
    $bot->add_handler('message channel', 'mslevent_chanmsg');

    $bot->add_handler('privcmd loadmsl', 'mslload');
    $bot->add_handler('privcmd msldump', 'msldump');
}

sub addMSLFunction {
    my ($cmd, $subref) = @_;

    $mslfunctions{$cmd}{ref} = $subref;
}

sub callMSLFunction {
    my ($name, $env, @args) = @_;

    if (exists($mslfunctions{$name}{ref})) {
        return &{$mslfunctions{$name}{ref}}($env, @args);
    }
}

sub initmsl_builtin {
    addMSLFunction('+', sub {
        my ($env, @args) = @_;

        print "dbug +: @args\n";

        return join("", @args);
    });

    addMSLFunction('echo', sub {
        my ($env, @args) = @_;

        pop @args;
        print "@args\n";
    });

    addMSLFunction('nick', sub {
        my ($env, @args) = @_;

        $bot->nick($args[0]);
    });

    addMSLFunction('msg', sub {
        my ($env, @args) = @_;

        print "msg $env->{chan} @args\n\n";

        my $msgchanraw = shift(@args);
        my $msgchan = $msgchanraw ne "#" ? $msgchanraw : $env->{chan};

        $bot->say($msgchan, "@args");
    });

    addMSLFunction('describe', sub {
        my ($env, @args) = @_;

        print "describe @args\n\n";

        my $msgchanraw = shift @args;
        my $msgchan = $msgchanraw ne "#" ? $msgchanraw : $env->{chan};

        $bot->emote($msgchan, "@args");
    });

    addMSLFunction('set', sub {
        my ($env, @args) = @_;

        print "@_\n";

        my $var = shift @args;
        print "dbug: setting $var to @args\n";
        $mslvars{$var} = "@args";
    });

    addMSLFunction('if', sub {
        my ($env, @args) = @_;

        shift @args;  # remove 'if';
        print "test: if (@args\n";

        my @runcode;

        while (scalar(@args) > 0) {
            next if ($args[0] eq "&&");

            my $left = shift @args;
            my $condition = shift @args;
            my $right = shift @args;

            while ($args[0] ne "else" && $args[0] ne "}") {
                print "dbug $p: $args[0]\n";
                push(@runcode, shift @args);
            }

            if ($args[-1] eq "}") {
                pop @args; # remove last
            }

            if ($condition eq "==") {
                if ($left eq $right) {
                
                    runMSL(join(" ", @runcode), %{ $env });
                    return 1;
                } else {
                    runMSL(join(" ", @args), %{ $env });
                    return 1;
                }
            }
        }
    });
}

sub runMSL {
    my ($code, %mslenv) = @_;
    my $retval, $i, $x, @args;

    print "runMSL called: $code - $mslenv{text}\n";

    $_[0] =~ s/\n//gs;
    $_[0] =~ s/\)$//;

    while ($code =~ /\$([\w+]?)\((.*?)\)/) {
        my @tmp = split(/\,/, $2);
                    
        for (my $j = 0; $j < scalar(@tmp); $j++) {
            print "dbug3: ".$tmp[$j]."\n";
            my $tmpstr = "";

            if ($tmp[$j] =~ /\%(\w+)/g) {
                $tmpstr = exists($mslvars{"\%$1"}) ? $mslvars{"\%$1"} : "%$1";
                $tmp[$j] =~ s/\%$1/$tmpstr/gs; 
            } elsif ($tmp[$j] =~ /\$(\w+)$/g) {
                $tmpstr = exists($mslenv{$1}) ? $mslenv{$1} : "\$$1";
                $tmp[$j] =~ s/\$$1/$tmpstr/gs; 
            }
        }


        print "calling \$$1(@tmp)\n"; 


        my $token = callMSLFunction($1, \%mslenv, @tmp);

        print "ret token: $token\n";

        $code =~ s/\$([\w+]?)\((.*?)\)/$token/g;
        runMSL($code, \%mslenv);
    } 


    my @codetokens  = split(/ /, shift @_);
    my $tokenlen    = scalar(@codetokens);
    my $arglen;
    my $ifmode = 0;
    my @ifblock;
    my $iflen = 0;
    my $bracketcnt = 0;

    for ($i = 0; $i < $tokenlen; $i++) {
        $codetokens[$i] = "if" if ($codetokens[$i] eq "&&");
        next if ($codetokens[$i] eq "" || $codetokens[$i] eq " ");

        if ($codetokens[$i] eq "if") {
            $ifmode = 1;
        }

        if ($codetokens[$i] eq "{") {
            $bracketcnt++;
        }

        if ($codetokens[$i] eq "}" || $i+1 == scalar(@codetokens)) {
            $bracketcnt--;

            if ($ifmode == 1) {

                if ($bracketcnt == 0) {
                    push(@ifblock, "}");

                    next if ($codetokens[$i+1] eq "else");

                    my $ret = callMSLFunction('if', \%mslenv, @ifblock);
                    $ifmode = 0;

                    my $skip = $i;
                    foreach my $elm (@ifblock) {
                        $skip++;
                    }

                    if ($ret == 1) {
                        $i = $skip + $iflen + scalar(@ifblock);
                    }

                    $iflen = 0;
                    @ifblock = ();
                }
            }
        }

        if ($ifmode == 1) {
            push(@ifblock, $codetokens[$i]);
            $iflen++;
        }

        print "token: $codetokens[$i]\n\n";

        if (exists($mslfunctions{$codetokens[$i]})) {
            $arglen = 0;
            @args = ();

            for ($x = $i+1; $x < $tokenlen; $x++) {
                last if ($codetokens[$x] eq "");
                last if ($x+1 == $tokenlen && $token eq "}");

                my $token = $codetokens[$x];
                print "token2: $token\n";

                if ($token =~ /\$(\d)\-/) {
                    my @tmp = split(/ /, $mslenv{text});
                    @tmp = splice(@tmp, $1);
                    $token = join(" ", @tmp);

                    print "dbug token: $token\n";
                } elsif ($token =~ /\$(\d)$/) {
                    @tmp = split(/ /, $mslenv{text});
                    $token = $tmp[$1];
                } elsif ($token =~ /\%(\w+)/) {
                    if ($codetokens[$i] eq "set" && $arglen == 0) {
                        $token = "%$1";
                    } else {
                        $token = exists($mslvars{"\%$1"}) ? $mslvars{"\%$1"} : "%$1";
                    }
                } elsif ($token =~ /\$(\w+)$/g) {
                    $token = exists($mslenv{$1}) ? $mslenv{$1} : "\$$1";
                }

                $arglen++;

                if ($ifmode == 1) {
                    push(@ifblock, $token);
                } else {
                    push(@args, $token);
                }
            }

            if ($ifmode != 1) {
                if ($codetokens[$i] ne "if") {
                    callMSLFunction($codetokens[$i], \%mslenv, @args);
                }
            }

            $i = $i + $arglen +1;
        }
    }

    return $retval;
}

sub mslOnEvent {
    my ($code, $eventType, $command, $chan) = @_;

    print "on @_\n";

    my $idx = scalar(@{$mslevents{$eventType}}) or 0;

    $command =~ s/\s\*$//;

    print "$idx\nCommand: $command\nCode: $code\n";

    $mslevents{$eventType}[$idx]{command} = $command;
    $mslevents{$eventType}[$idx]{chan} = $chan if ($chan);
    $mslevents{$eventType}[$idx]{code} = $code; 
}

sub parseFile {
    my ($file) = @_;;

    open(my $fh, "<./modules/msl/$file") or $bot->err($!);
    my @contents = <$fh>;
    close($fh) or $bot->err($!);

    my $line, @linechars, $codebuf, $oldidx;
    my $bracketmode = 0;
    my $bracketcnt  = 0;
    my $start = 0;

    for (my $i = 0; $i < scalar(@contents); $i++) {
        next if ($contents[$i] eq "|");
        $contents[$i] = " " if ($contents[$i] eq "\n");

        $line = $contents[$i];

        if ($line =~ /on\s(.*?):(.*?):(.*?):(.*?):(.*)/gmi || $line =~ /on\s(.*?):(.*?):(.*?):(.*)/gmi) {
            @linechars = split(//, $line);

            print "dbug parser: on : $1 | $2 | $3 | $4\n";

            if ($4) {
                $start = length("on $1:$2:$3:$4:");
            } else {
                $start = length("on $1:$2:$3:");
            }

            for (my $x = $start; $x < scalar(@linechars); $x++) {
                $codebuf .= $linechars[$x]; # ne "\n" ? $linechars[$x] : " | ";

                if ($linechars[$x] eq "{") {
                    $bracketmode = 1;
                    $bracketcnt++;
                }

                if ($linechars[$x] eq "}") {
                    $bracketcnt--;

                    if ($bracketcnt == 0) {
                        $bracketmode = 0;
                    }
                }
            }

            if ($bracketmode == 1) {
                $oldidx = $i;
                
                while ($bracketcnt != 0) {
                    $i++;

                    #$contents[$i] =~ s/^\s+//gs;
                    
                    @linechars = split(//, $contents[$i]);

                    for (my $x = 0; $x < scalar(@linechars); $x++) {
                        $codebuf .= $linechars[$x]; # ne "\n" ? $linechars[$x] : " | ";

                        if ($linechars[$x] eq "{") {
                            $bracketcnt++;
                        }

                        if ($linechars[$x] eq "}") {
                            $bracketcnt--;

                            if ($bracketcnt lt 0)
                            {
                                $bracketmode = 0;
                            }
                        }
                    }
                }

                $i = $oldidx;
            }

            if ($4) {
                $codebuf =~ s/on \Q$1:\Q$2:\Q$3:\Q$4: //;
                mslOnEvent($codebuf, $2, $3, $4);
            } else {
                $codebuf =~ s/on \Q$1:\Q$2:\Q$3: //;
                mslOnEvent($codebuf, $2, $3);
            }
    
            $codebuf = "";
            $bracketmode = 0;
            $bracketcnt = 0;
        }
    }
    
}


sub mslevent_chanmsg {
    my ($nick, $host, $chan, $text) = @_;

    for (my $i = 0; $i < scalar(@{$mslevents{TEXT}}); $i++) {
        if ($text =~ /^\Q$mslevents{TEXT}[$i]{command}/) {
            $text =~ s/\s\*$//;

            if ($mslevents{TEXT}[$i]{chan} eq "#") {
                runMSL($mslevents{TEXT}[$i]{code}, (
                    nick => $nick,
                    host => $host,
                    chan => $chan,
                    text => "$mslevents{TEXT}[$i]{command} $text"
                ));
            }
        } elsif ($mslevents{TEXT}[$i]{command} eq "*") {
            runMSL($mslevents{TEXT}[$i]{code}, (
                nick => $nick,
                host => $host,
                chan => $chan,
                text => "$mslevents{TEXT}[$i]{command} $text"
            ));
        }
    }
}

sub mslevent_action {
    print "action: @_\n";
    my ($nick, $chan, $text) = @_;

    $text =~ s/^\s//;

    for (my $i = 0; $i < scalar(@{$mslevents{ACTION}}); $i++) {
        if ($text =~ /^\Q$mslevents{ACTION}[$i]{command}/) {
            $text =~ s/\s\*$//;

            if ($mslevents{ACTION}[$i]{chan} eq "#") {
                runMSL($mslevents{ACTION}[$i]{code}, (
                    nick => $nick,
                    chan => $chan,
                    text => "$mslevents{ACTION}[$i]{command} $text"
                ));
            }
        } elsif ($mslevents{ACTION}[$i]{command} eq "*") {
            runMSL($mslevents{ACTION}[$i]{code}, (
                nick => $nick,
                chan => $chan,
                text => "$mslevents{ACTION}[$i]{command} $text"
            ));
        }
    }
}

sub mslevent_nick {
    print "nick @_\n";
    my ($nick, $host, $newnick, @channels) = @_;

    for (my $i = 0; $i < scalar(@{$mslevents{NICK}}); $i++) {
        print "dbug: $mslevents{NICK}[$i]{chan}\n";
        if ($mslevents{NICK}[$i]{chan} eq "#") {
            print "calling it\n";
            runMSL($mslevents{NICK}[$i]{code}, (
                nick => $nick,
                host => $host,
                newnick => $newnick
            ));
        }
    }
}


sub mslload {
    my ($nick, $host, $text) = @_;

    if ($bot->isbotadmin($nick, $host)) {
        $bot->notice($nick, "Loading MSL script: $text");
        parseFile($text);
    } else {
        $bot->notice($nick, "Access denied.");
    }
}

sub msldump {

}

sub unloader {
    $bot->del_handler('ctcp action', 'mslevent_action');
    $bot->del_handler('event nick', 'mslevent_nick');
    $bot->del_handler('message channel', 'mslevent_chanmsg');
    $bot->del_handler('privcmd loadmsl', 'mslload');
}

1;
