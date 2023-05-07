# termenv.pl - Define functions for the WebTerminal

sub echo {
    $WebAdmin::outbuf{$client} .= shift."\n";
}

sub help {
    my $topic = shift;

    if (!$topic) {
        echo("[[b;;]Commands:] irc, say, echo, clear, load, unload, reload, viewlog, sys");
        echo("\n ");
        echo("This console uses Perl for it's shell. (Perl Version: $^V)");
        echo("Use [[b;;]help \"<subtopic>\"] for help information on individual commands.");
    } elsif ($topic =~ /say/) {
        echo("[[b;;]Syntax:] say(\"<target>\", \"<msg>\")\n \nSends \$msg to \$target on IRC.");
    } elsif ($topic =~ /echo/) {
        echo("[[b;;]Syntax:] echo(\"<msg>\")\n \nPrints \$msg to the terminal.");
    } elsif ($topic =~ /clear/) {
        echo("[[b;;]Syntax:] clear\n \nClears the terminal.")
    } elsif ($topic =~ /unload/) {
        echo("[[b;;]Syntax:] unload(\"<module>\")\n \nUnloads <module>.");
    } elsif ($topic =~ /reload/) {
        echo("[[b;;]Syntax:] reload(\"<module>\")\n \nReloads <module>.");
    } elsif ($topic =~ /load/) {
        echo("[[b;;]Syntax:] load(\"<module>\")\n \nLoads <module>.");
    } elsif ($topic =~ /viewlog/) {
        echo("[[b;;]Syntax:] viewlog(\"<opts>\")\n \nPrints the last 15 lines from the log to the terminal\nUse [[b;;]--full] in <opts> for full log.")
    } elsif ($topic =~ /sys/) {
        echo("[[b;;]Syntax:] sys(\"<command>\")\n \nRuns the <command> on the host system and prints it's output to the terminal.");
    } elsif ($topic =~ /irc/) {
        echo ("[[b;;]Syntax:] irc(\"<command>\")\n \nRuns the IRC <command>, see [[b;;]irc \"help\"] for more commands.");
    }
}

sub say {
    $bot->say(@_);
}

sub sys {
    foreach my $line (`$_[0]`) { echo($line); }
}

sub reload {
    my $mod = shift;

    echo("[[b;lightgreen;]Reloading $mod]");

    $bot->unload_module($mod);
    $bot->load_module($mod);
}

sub load {
    my $mod = shift;

    echo("[[b;lightgreen;]Loading $mod]");
    
    $bot->load_module($mod);
}

sub unload {
    my $mod = shift;

    echo("[[b;lightgreen;]Unloading $mod]");

    $bot->unload_module($mod);
}

sub viewlog {
    my $mode = shift;

    if ($mode eq "--full") {
        foreach my $l (@Shadow::Core::log) {
            $tmp =~ s/\]/\x07/gs;
            $tmp =~ s/\[/\x08/gs;
            echo("[[b;#4AF626;]$l]");
        }
    } else {
        for (my $i = -15; $i < 0; $i++) {
            my $tmp = $Shadow::Core::log[$i];
            $tmp =~ s/\]/\x07/gs;
            $tmp =~ s/\[/\x08/gs;

            echo("[[b;#4AF626;]$tmp]");
        }
    }
}

sub irc {
    my $cmdraw = shift;
    my @tmp  = split(/ /, $cmdraw);
    my $cmd  = shift @tmp;
    my $args = join(" ", @tmp);

    Shadow::Core::handle_handler('privcmd', $cmd, $host, "-TERM-", $args);
}