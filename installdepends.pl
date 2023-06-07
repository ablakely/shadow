#!/usr/bin/perl -w

# Shadow Dependency Installer
# Written by Aaron Blakely
#
# This automatically installs dependencies for .pm files in the modules dir using cpan,
# it also supports embedded shell scripts in a module's comments that are ran at install time using #$INSCRIPT comments.
#
# Example:
#   #$INSCRIPT[sh]
#   #  echo "hello from sh"
#   #  if [ ! -d "./modules/LargeModule" ]; then
#   #    git clone https://../LargeModule.git ./modules/LargeModule
#   #  fi
#   #$INSCRIPT[sh]
#
# Larger modules with dependencies not in the main .pm in modules can also use #$INDEP statements.
#
# Example:
#   #$INDEP[Foo::Bar Foo::Bar2]
#

use strict;
use warnings;
use CPAN;
use lib './modules';

my @dependsRaw;
my @depends;

# Core Dependencies
push(@dependsRaw, "JSON");
push(@dependsRaw, "Digest::SHA");

# OS-specific for BotStats
if ($^O eq "msys" || $^O eq "MSWin32") {
  push(@dependsRaw, "Win32::OLE");
} elsif ($^O eq "linux") {
  push(@dependsRaw, "Proc::ProcessTable");
} else {
  print "[Warning] BotStats module only supports Windows or Linux, it will not be available on this install.\n";
}

sub sortArray {
	my %seen;
	grep !$seen{$_}++, @_;
}

# Get a dir listing
opendir(MODS, "./modules") or die $!;
while (my $file = readdir(MODS)) {
	if ($file =~ /\.pm/) {
		open(MODFILE, "<./modules/$file") or die $!;
        my $inscript = "";
        my $capture  = 0;
        my $interp   = `which sh 2>&1`;
        chomp $interp;
        my $pretty = "";

		while (my $line = <MODFILE>) {
            if ($line =~ /^\#\$INSCRIPT(\[(.*?)\])?/) {
                if (!$capture && $2) {
                    $capture = 1;
                    $interp = `which $2 2>&1`;
                    my $reqinterp = $2;

                    if ($interp =~ /which\: no .*? in/) {
                        print "\nError: No '$reqinterp' interpreter found for install script in $file. Ignoring script.\n\n";
                        $capture = 0;
                    }
                } else {
                    $capture = 0;
                    chomp $interp;

                    unless ($interp =~ /which\: no .*? in/) {
                        if ($^O eq "msys" || $^O eq "MSWin32") {
                            print "\nWARNING: #\$INSCRIPT install scripts will usually fail on Windows unless you are running with cygwin or another Unix-like enviornment.\n";
                        }

                        print "Running install script from $file using $interp:\n$pretty\n";
                        $pretty = "";

                        open(my $fh, ">", ".tmpinstall.script") or die $!;
                        print $fh $inscript;
                        close($fh) or die $!;

                        system("$interp ./.tmpinstall.script");
                        unlink("./.tmpinstall.script");
                    }
                }
            } elsif ($capture) {
                $line =~ s/\r//gs;
                $pretty .= $line;
                $line =~ s/^\#\s+//;
                $inscript .= $line;
            }

			if ($line =~ /use (.*);/) {
				my ($pkg, $arg) = split(/ /, $1);
				print " -- Found $pkg in $file, adding to install list.\n";
				push(@dependsRaw, $pkg) if $pkg ne "open";
			} elsif ($line =~ /\#\$INDEP\[(.*?)\]/) {
                my @pkgs = split(/\s/, $1);

                foreach my $pkg (@pkgs) {
				    print " -- Found $pkg in #\$INDEP statement in $file, adding to install list.\n";
                    push(@dependsRaw, $pkg);
                }
            }
		}

		close(MODFILE);
	}
}
closedir(MODS);

@depends = sortArray(@dependsRaw);

foreach my $mod (@depends) {
    next if ($mod =~ /Shadow\:\:/);

	print "Checking for $mod...";
	eval "require $mod";

	if ($@) {
		print "Not found.\nInstalling...\n";
		install($mod);
	} else {
		print "Excellent!\n";
	}
}

print "\nDone.  Your environment is now prepared for shadow.\n";
print "Make sure you edit etc/shadow.conf then run ./shadow\n";
my $whome = `whoami`;
chomp $whome;
print "Party on, ".$whome."!\n";
