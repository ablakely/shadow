# Shadow::Core v1.0	- Core Module for Shadow IRC Bot
# Written by Aaron Blakely <aaron@ephasic.org>
# Supports:
#	/Most/ IRCd's - Since it scans 005 of the PREFIXES
#


package Shadow::Core;

use Carp qw(cluck confess longmess);
use Encode qw(encode);
use strict;
use warnings;
use IO::Select;
use IO::Socket::INET;
use Config;
use Shadow::Admin;
use Shadow::Help;

# Global Variables, Arrays, and Hashes
our ($cfg, $cfgparser, $sel, $ircping, $checktime, $irc, $nick, $lastout, $myhost, $time, $tickcount, $debug, $connected);
our (@queue, @timeout, @loaded_modules, @onlineusers, @botadmins);
our (%server, %options, %handlers, %sc, %su, %sf, %inbuffer, %outbuffer, %users, %modreg, %log, %storage);

my $omode = 0;
our $tmpclient;

%options = (
	'flood' => {
		hostnum		=> 10,
		nickbnum	=> 4,
		nicknum		=> 8,
		allbnum		=> 6,
		hostbnum	=> 5,
		typebnum	=> 3,
		btime		=> 5,
		typenum		=> 6,
		allnum		=> 12,
		'time'		=> 30,
	},
	config => {
		version		=> 'Shadow v1.3 (https://github.com/ablakely/shadow)',
	},
	irc => {
		q_prefix	=> '~',
		a_prefix	=> '&',
		o_prefix	=> '@',
		h_prefix	=> '%',
		v_prefix	=> '+',
		cmdprefix	=> '.',
	},

);

# Ignore warnings caused by misues of Perl
$SIG{__WARN__} = sub {
    my $warning = shift;

    if ($warning =~ /Subroutine .* redefined at/) {
    	return; # caused by reloading modules
    } elsif ($warning =~ /keys on reference is experimental/) {
    	return;
    } elsif ($warning =~ /Useless use of/ && $warning =~ /[Routes\.pm|Router\.pm]/) {
        return; # lines 307 in Routes.pm and 14 in Router.pm
    } elsif ($warning =~ /Illegal character in prototype for \? \: \$rss/ && $warning =~ /RSS\.pm/) {
        return; # line 409 in RSS.pm
    }

    err(0, "[Interpreter Warning] $warning", 0, "Perl");
};

# Constructor
sub new {
	my $class				= shift;
	my $self				= {};
	my ($conffile, $verbose, $nofork)  = @_;

    if (!$conffile) {
        return $class;
    }

	$cfgparser      = Shadow::Config->new($conffile, $verbose);
	$cfg            = $cfgparser->parse();
	$options{cfg}   = $cfg;

	if (my $cmdprefix = $cfg->{Shadow}->{IRC}->{bot}->{cmdprefix}) {
		$options{irc}{cmdprefix} = $cmdprefix;
	}

	$debug = $verbose;
	my @serverlist  = @{$cfg->{Shadow}->{IRC}->{bot}->{host}};

	# $ENV overrides
	$cfg->{Shadow}->{IRC}->{bot}->{cmdchan} = $ENV{IRC_CMDCHAN} if exists($ENV{IRC_CMDCHAN});
	$cfg->{Shadow}->{IRC}->{bot}->{admins}  = split(/,/, $ENV{IRC_ADMINS}) if exists($ENV{IRC_ADMINS});

	if ($cfg->{Modules}->{WebAdmin}->{httpd}->{publicURL} && exists($ENV{HTTP_PUBURL})) {
		$cfg->{Modules}->{WebAdmin}->{httpd}->{publicURL} = $ENV{HTTP_PUBURL};
	}

	foreach my $ircserver (@serverlist) {
		my ($serverhost, $serverport)	= split(/:/, $ircserver);

		$serverhost = $ENV{IRC_HOST} if exists($ENV{IRC_HOST});
		$serverport = $ENV{IRC_PORT} if exists($ENV{IRC_PORT});

		$server{$serverhost}		= {};
		$server{$serverhost}{port}	= $serverport || 6667;
	}

	# generate a alternative nickname from the account thats executing the bot if no nick is defined
	# Example: the user is named 'aaron', then the bot will be named 'aaronbot'
	my $whoami = `whoami`;
	chomp $whoami;
	$whoami .= "bot";
	$options{config}{nick}		= $ENV{IRC_NICK} || $cfg->{Shadow}->{IRC}->{bot}->{nick} || $whoami;
	$options{config}{name}		= $ENV{IRC_NAME} || $cfg->{Shadow}->{IRC}->{bot}->{name} || $nick;
	$options{config}{reconnect}	= 200;

	# to put something in there
	$Shadow::Core::nick = $nick;

	# Push the loaded modules into our array
	foreach my $modname (sort keys %INC) {
		$modname				=~ s/\//\:\:/gs;	# replace / with ::
		$modname				=~ s/\.pm$//;		# remove the .pm
		$loaded_modules[++$#loaded_modules] 	= $modname;
	}

	if (!$nofork) {
		exit if (fork());
		exit if (fork());
		sleep 1 until getppid() == 1;

		$verbose = 0;
	}

	if (!$verbose) {
		open (STDOUT, ">./shadow.log") or die $!;
		open (STDERR, ">./shadow.log") or die $!;
	}

	$self->{cfg} = $cfg;
	$self->{help}  = Shadow::Help->new(bless($self, $class));
	$self->{admin} = Shadow::Admin->new(bless($self,$class));

	$self->{starttime} = time();

	$tickcount = 0;

	return bless($self, $class);
}

sub rehash {
	my $self = shift;

	$cfg = $cfgparser->parse();
	$options{cfg} = $cfg;

	Shadow::Core::log(1, "Rehashing configuration file...", "System");

	handle_handler('event', 'rehash', $cfg);
}

sub updatecfg {
	my ($self, $cfg) = @_;

	open(my $fh, ">", "./etc/shadow.conf") or return err($self, "[WebAdmin] Cannot write config: $!");
    #select($fh);
    
	print $fh $cfg;
	close($fh);
}

# We'll handle our module stuff here

sub shadowuse {
	my $self = shift;
	my ($mod) = @_;
	my $caller = caller;

	eval "package $caller; use $mod;";
	$loaded_modules[++$#loaded_modules] = $mod;
}

sub log {
	my ($self, $string, $queue) = @_;
	err($self, $string, 0, $queue);
}

sub err {
	my ($self, $err, $fatal, $queue) = @_;
	if (!$fatal) {
		$fatal = 0;
	}

	if (!$queue) {
		$queue = "System";
	}


	chomp $err;

	if ($debug) {
	    print("$err\n");
	}

	if ($err =~ /Error/i || $queue eq "Perl") {
        my $q = $queue eq "Perl" ? "Perl" : "Error";

		push(@{$log{$q}}, $err);
    
        my $i = 1;
        push(@{$log{$q}}, "Stack Trace:");
        while ( (my @call_details = (caller($i++))) ){
            push(@{$log{$q}}, "    ".$call_details[1].":".$call_details[2]." in function ".$call_details[3]);
            print "    ".$call_details[1].":".$call_details[2]." in function ".$call_details[3]."\n";
        }
    }

	push(@{$log{$queue}}, $err);
	push(@{$log{All}}, $err) unless ($queue eq "Perl");

	my $cmdchan = $cfg->{Shadow}->{IRC}->{bot}->{cmdchan};

	if ($fatal) {
		irc_raw(1, "PRIVMSG $cmdchan :[FATAL] Encountered fatal error.  Exiting...");
		confess "\n[FATAL] Encountered fatal error.  Exiting...\n";
	} else {
		foreach my $cmdchanlogtype (@{$cfg->{Shadow}->{IRC}->{bot}->{cmdchanlogtype}}) {
			if ($queue eq $cmdchanlogtype || $cmdchanlogtype eq "All") {
				irc_raw(1, "PRIVMSG $cmdchan :$err");
			}
		}
	}
}

sub isloaded {
	my ($self, $module_name) = @_;
	
	foreach my $loaded_mod (@loaded_modules) {
		if ($loaded_mod eq "Shadow::Mods::".$module_name) {
			return 1;
		}
	}

	return 0;
}

sub load_module {
	my ($self, $module_name) = @_;

	if (-e "modules/$module_name\.pm") {
		foreach my $loaded_mod (@loaded_modules) {
			if ($loaded_mod eq "Shadow::Mods::".$module_name) {
				err(1, "Refusing to load $module_name: module already loaded.", 0, "Modules");
				return;
			}
		}

		Shadow::Core::log(1, "Loading module: $module_name", "Modules");
		require "modules/$module_name\.pm";

		eval "$module_name->loader();";
		if ($@) {
			err(1, "[Core/load_module/$module_name] eval error: $@", 0, "Modules");
		}
		$loaded_modules[++$#loaded_modules] = "Shadow::Mods::".$module_name;
		handle_handler('module', 'load', $module_name);
		return 1;
	} else {
		err(1, "Error: No such module $module_name", 0, "Modules");
		return 0;
	}
}

sub unload_module {
	my ($self, $module_name) = @_;

	foreach my $loaded_mod (@loaded_modules) {
		if ($loaded_mod eq "Shadow::Mods::".$module_name) {
            handle_handler('module', 'unload', $module_name);
			eval "$module_name->unloader();";
			if ($@) {
				err(1, "[Core/unload_module/$module_name] eval error: $@", 0, "Modules");
			}

			delete $INC{'modules/'.$module_name.'.pm'};

			for my $i (reverse 0 .. $#loaded_modules) {
				if ($loaded_modules[$i] eq "Shadow::Mods::".$module_name) {
					splice(@loaded_modules, $i, 1, ());
				}
			}

			return 1;
		}
	}

	return undef;
}

sub reload_module {
	my ($self, $module_name) = @_;

	foreach my $loaded_mod (@loaded_modules) {
		if ($loaded_mod eq "Shadow::Mods::".$module_name) {

            return 0 if (!$self->unload_module($module_name));
            return 0 if (!$self->load_module($module_name));


            handle_handler('module', 'reload', $module_name);
            return 1;
        }
    }

    return 0;
}

sub register {
	my ($self, $name, $version, $author, $desc) = @_;

    return 0 if (!$name);

	$modreg{$name} = {};
	$modreg{$name}{version}     = $version ? $version : "N/A";
	$modreg{$name}{author}      = $author ? $author : "N/A";
    $modreg{$name}{description} = $desc ? $desc : "N/A";

    return 1;
}

sub unregister {
	my ($self, $name) = @_;

	if (exists($modreg{$name})) {
		delete $modreg{$name};

        return 1;
	}

    return 0;
}

sub getmodinfo {
    my ($self, $mod) = @_;

    return exists($modreg{$mod}) ? $modreg{$mod} : 0;
}

sub module_stats {
	my ($self) = @_;

	my %modinfo;
	my $modcount = 0;

	foreach my $mod (@loaded_modules) {
		$modcount++;
		$modinfo{$mod} = {};
		$modinfo{$mod}{version} = 1;
	}

	$modinfo{loadedmodcount} = $modcount;

	return %modinfo;
}

# persistant module storage
sub store {
    my ($self, $key, $val) = @_;

    $storage{$key} = $val;
}

sub retrieve {
    my ($self, $key) = @_;

    if (exists($storage{$key})) {
        return $storage{$key};
    }

    return undef;
}

sub storage_exists {
    my ($self, $key) = @_;

    return exists($storage{$key});
}

# IRC connection stuff

sub connect {
	$sel		= new IO::Select;
	$ircping	= time;
	$checktime	= time;
	$lastout	= 0;
	irc_reconnect();
	mainloop();
}

# Our IO stuff

sub sendfh {
	my ($fh, $text) = @_;
	$outbuffer{$fh} .= $text if $fh;
}

sub flush_out {
	my $fh = shift;
	return unless defined $outbuffer{$fh};

	$outbuffer{$fh} = encode('UTF-8', $outbuffer{$fh});
	my $sent = syswrite($fh, $outbuffer{$fh}, 1024);
	return if !defined $sent;

	if (($sent == length($outbuffer{$fh})) || ($! == 11)) {
		substr($outbuffer{$fh}, 0, $sent) = '';

		if (!length($outbuffer{$fh})) {
			delete $outbuffer{$fh};
		}
	} else {
		closefh($fh);
	}
}

sub closefh {
	my ($fh) = shift;

	$ircping = 200 if defined $irc and $fh == $irc;
	flush_out($fh);
	$sel->remove($fh);
	close($fh);
}

# Our mainloop which keeps the bot alive

sub mainloop {
	while (1) {
		$tickcount++;
		handle_handler('event', 'tick', $tickcount);

		foreach my $fh ($sel->can_read(1)) {
			my ($tmp, $char);
			$tmp = sysread($fh, $char, 1024);
			close $fh unless defined $tmp and length $char;
			$inbuffer{$fh} .= $char;

			while (my ($theline, $therest) = $inbuffer{$fh} =~ /([^\n]*)\n(.*)/s) {
				$inbuffer{$fh} = $therest;
				$theline =~ s/\r$//;
				irc_in($theline, $fh);
			}
		}

		my $count = 0;
		my $time = time;

		for my $num (0 .. 3) {

			last if ($lastout >= $time);
			while ($_ = shift(@{$queue[$num]})) {
				if (length($_) > 512) {
					$_ = substr($_, 0, 511);
				}
				sendfh($irc, $_);

				if (length($_) > 400) {
					$lastout = $time + 5;
					$count++;
					last;
				}
				$count++;

				if ($lastout < $time - 20) {
					$lastout = $time - 20;
					next;
				}
				elsif ($lastout < $time - 15) {
					$lastout = $time - 15;
					next;
				}
				elsif ($lastout < $time - 10) {
					$lastout = $time - 10;
					next;
				} else {
					$lastout = $time + 1;
				}
				last if $count >= 1;
			}
			last if $count >= 1;
		}

		foreach my $fh ($sel->can_write(0)) {
			flush_out($fh);
		}

		if ($ircping + 60 < $time && $checktime + 30 < $time) {
			$checktime = $time;

			irc_raw(3, "NOTICE $nick :anti-reconnect") if ($nick); # ping fail back
		}

		if ($ircping + $options{config}{reconnect} <= $time) {
            $connected = 0;
            irc_reconnect()
        }

		for (@timeout) {
			if (defined($_->{'time'}) && $time >= $_->{'time'}) {
				delete($_->{'time'});
				my ($module, $sub) = ($_->{module}, $_->{'sub'});
				eval("$module->$sub();");
				if ($@) {
					err(1, "[Core/mainloop/timers/$module/$sub] eval error: $@", 0, "Modules");
				}
			}
		}
	}
}

# IRC processing and events

sub irc_connect {
	my ($ircserver, $ircport) = split(/:/, $_[0], 2);

	Shadow::Core::log(1, "Connecting to IRC server... [server=$ircserver, port=$ircport]", 0, "System");
	$irc = IO::Socket::INET->new(
		Proto		=> 'TCP',
		PeerAddr	=> $ircserver,
		PeerPort	=> $ircport,
	) or return undef;

	sendfh($irc, "NICK ".$options{config}{nick}."\r\n");
	sendfh($irc, "USER shadow ".lc($options{config}{nick})." ".lc($ircserver)." :".$options{config}{name}."\r\n");

	$sel->add($irc);
	$ircping = time;
	return $irc;
}

sub irc_disconnect {
	$sel->remove($irc);
	close($irc);
	$irc		= undef;
	%sc		= ();
}

sub irc_reconnect {
	irc_disconnect() if defined $irc;

	until ($irc) {
		for (keys %server) {
			return if $irc = irc_connect($_.":".$server{$_}{port});
		}

		sleep 20 if !$irc;
	}
}

# IRC events processor

sub irc_in {
	my ($response, $fh) = @_;
	$ircping = time;
	handle_handler("raw", "in", $response);

	if ($response =~ /^PING (.*)$/) {
		irc_raw(0, "PONG $1");
	}
	elsif ($response =~ /^NOTICE (.*)$/) {
		handle_handler('raw', 'noticeUP', $1);
	}
	elsif ($response =~ /^ERROR/) {
		$ircping = time - 100;
		%sc	 = ();
	} else {
		$response 		=~ s/^:([^ ]+) //;
		my $ck       		= $1;
		my ($command, $text) 	= split(/:/, $response, 2);

		my @bits		= split(' ', "$ck $command");
		return if !defined $bits[1];
		my ($remotenick, $remotehost) = split("!", $bits[0]);
		handle_handler("raw", lc($bits[1]), $remotenick, $remotehost, $text, @bits);

		if ($bits[1] eq "004") {
		    # connected event
		    irc_connected($bits[2]);

		    my @chans = exists($ENV{IRC_CHANS}) ? split(/,/, $ENV{IRC_CHANS}) : @{$cfg->{Shadow}->{IRC}->{bot}->{channels}};
		    foreach my $channel (@chans) {
					Shadow::Core::log(1, "Attempting to join $channel", "System");
					irc_raw(1, "JOIN :$channel");
		    }

			  Shadow::Core::log(1, "Attempting to join cmdchan: ".$cfg->{Shadow}->{IRC}->{bot}->{cmdchan}, "System");
			  irc_raw(1, "JOIN :".$cfg->{Shadow}->{IRC}->{bot}->{cmdchan});
		}
		elsif ($bits[1] eq "005") {
		  # scan 005 info for adapting to our enviornment
		  irc_scaninfo(@bits);
		}
		elsif ($bits[1] eq "433") {
		  # nickname is in use event
		  irc_nicktaken($bits[3]);
		}
		elsif ($bits[1] eq "381") {
		  # oper event
		  irc_becameOper();
		}
		elsif ($bits[1] eq "353") {
		  # names event
		  irc_users($bits[4], split(/ /, $text));
		}
		elsif ($bits[1] eq "MODE") {
		  # mode event
		  my $mode = join(" ", @bits[2 .. scalar(@bits) - 1]) if defined $bits[2];
		  $mode .= " $text" if defined $text;
		  irc_mode($mode, $remotenick, $bits[0]);
		}
		elsif ($bits[1] eq "PRIVMSG") {
		  # privmsg event
		  irc_msg_handler($remotenick, $bits[2], $text, $bits[0]);
		}
		elsif ($bits[1] eq "JOIN") {
		  # join event

		  if (!$text) {
		    # support for charybdis 3.5.2

		    ($command, $text) = split(/ /, $command);
		  }

		  irc_join($text, $remotenick, $bits[0]);
		}
		elsif ($bits[1] eq "PART") {
		  # part event
		  irc_part($bits[2], $remotenick, $bits[0], $text);
		}
		elsif ($bits[1] eq "QUIT") {
		  # quit event
		  irc_quit($remotenick, $bits[0], $text);
		}
		elsif ($bits[1] eq "NOTICE") {
		  # notice event
		  irc_notice($remotenick, $bits[2], $text, $bits[0]);
		}
		elsif ($bits[1] eq "NICK") {
		  # nick change event

		  # support for charybdis 3.5.2
		  if (!$bits[2]) {
		      irc_nick($remotenick, $text, $bits[0]);
		  } else {
		      irc_nick($remotenick, $bits[2], $bits[0]);
		  }
		}
		elsif ($bits[1] eq "INVITE") {
		  # invite event
		  irc_invite($remotenick, $bits[3], $text, $bits[0]);
		}
		elsif ($bits[1] eq "KICK") {
		  # kick event
		  irc_kick($remotenick, $bits[2], $bits[3], $text, $bits[0]);
		}
		elsif ($bits[1] eq "473" || $bits[1] eq "475" || $bits[1] eq "479") {
		  # knock event
		  irc_knock($remotenick, $bits[3], $text, $bits[0]);
		}
		elsif ($bits[1] eq "302") {
			irc_userhost($text);
			handle_handler('raw', 'userhost', $bits[2], $text);
		}
		elsif ($bits[1] eq "311") {
			irc_userhost($bits[3], $bits[4]."\@".$bits[5]);
		}
		elsif ($bits[1] eq "366") {
			# end of /NAMES event
			if (!$text) {
		    # support for charybdis 3.5.2

		    ($command, $text) = split(/ /, $command);
		  }

		  handle_handler('event', 'namesend', $bits[3]);
		}
		elsif ($bits[1] eq "332") {
		  # topic event
		  $sc{lc($bits[3])}{topic}{text} = $text;
		}
		elsif ($bits[1] eq "333") {
		  # topic info event
		  $sc{lc($bits[3])}{topic}{by}     = $bits[4];
		  $sc{lc($bits[3])}{topic}{'time'} = $bits[5];
		}
		elsif ($bits[1] eq "TOPIC") {
		  # topic event
		  irc_topic($remotenick, $bits[2], $text, $bits[0]);
		}

	}
}

# IRC event parsers
sub irc_scaninfo {
	my @data = @_;
	foreach my $line (@data) {
		if ($line =~ /PREFIX\=(.*)/) {
			my $prefixes_unfmt = $1;
			my ($letters_unfmt, $symbols_unfmt) = split(/\)/, $prefixes_unfmt);

			# remove the '(' from letters
			$letters_unfmt =~ s/\(//;

			my @letters = split(//, $letters_unfmt);
			my @symbols = split(//, $symbols_unfmt);

			for (my $count = 0; $count != $#letters; $count++) {
				if ($letters[$count] eq 'q') {
					$options{irc}{q_prefix}		= $symbols[$count];
					next;
				}
				elsif ($letters[$count] eq 'a') {
					$options{irc}{a_prefix}		= $symbols[$count];
					next;
				}
				elsif ($letters[$count] eq 'o') {
					$options{irc}{o_prefix}		= $symbols[$count];
					next;
				}
				elsif ($letters[$count] eq 'h') {
					$options{irc}{h_prefix}		= $symbols[$count];
					next;
				}
				elsif ($letters[$count] eq 'v') {
					$options{irc}{v_prefix}		= $symbols[$count];
					next;
				}
			}
		}
	}
}

sub irc_becameOper {
	my $self = shift;
	Shadow::Core::log(1, "Oper credentials accepted", "System");
	$omode = 1;
	handle_handler('event', 'oper', 1);
}

sub isOperMode {
	my $self = shift;
	if ($options{cfg}->{Shadow}->{IRC}->{bot}->{oper}) {
		return 1;
	}

	return undef;
}

sub isOper {
	my $self = shift;
	return $omode;
}

sub irc_connected {
	$nick = shift;
	mode($nick, "+iB");
	handle_handler('event', 'connected', $nick);

	if ($options{cfg}->{Shadow}->{IRC}->{bot}->{oper}) {
		my @o = @{$options{cfg}->{Shadow}->{IRC}->{bot}->{oper}};
		irc_raw(1, "OPER $o[0] :$o[1]");
	}

    $connected = 1;
}

sub irc_nicktaken {
	my ($taken) = @_;
	my $cfgnick = $options{cfg}->{Shadow}->{IRC}->{bot}->{nick};

	Shadow::Core::log(1, "Nickname [$cfgnick] is currently in use.", "System");
	if ($taken) {
		my $tmpnick = $cfgnick . int(rand(9)) . int(rand(9)) . int(rand(9));
		Shadow::Core::log(1, "Using new nickname: $tmpnick", "System");

		$nick = $tmpnick;
		irc_raw(1, "NICK :$tmpnick");
		handle_handler('event', 'nicktaken', $cfgnick, $tmpnick);
	}
}

sub irc_users {
	my ($channel, @users) = @_;

	my $ul = join(" ", @users);
	$ul =~ s/[\+|\%|\@|\&\~]//gs;
		
	irc_raw(1, "userhost $ul"); # Figure out our user hosts

	if ($omode) {
		foreach my $user (@users) {
			$user =~ s/[\+|\%|\@|\&|\~]//gs;

			irc_raw(1, "whois $user") if ($user ne $nick);
		}
	}

	for (@users) {
		my ($owner, $protect, $op, $halfop, $voice);
		$owner				= 1 if /\Q$options{irc}{q_prefix}/;
		$protect			= 1 if /\Q$options{irc}{a_prefix}/;
		$op				    = 1 if /\Q$options{irc}{o_prefix}/;
		$halfop				= 1 if /\Q$options{irc}{h_prefix}/;
		$voice				= 1 if /\Q$options{irc}{v_prefix}/;

		$_ =~ s/\Q$options{irc}{q_prefix}//;
		$_ =~ s/\Q$options{irc}{a_prefix}//;
		$_ =~ s/\Q$options{irc}{o_prefix}//;
		$_ =~ s/\Q$options{irc}{h_prefix}//;
		$_ =~ s/\Q$options{irc}{v_prefix}//;
		$_ =~ s/\\//;

		# create a hash for the user
		$sc{lc($channel)}{users}{$_}		= {};
		$sc{lc($channel)}{users}{$_}{op}	= 1 if ($op || $protect || $owner); # let's assume anyone with +a and +q are also +o
		$sc{lc($channel)}{users}{$_}{protect}	= 1 if $protect;
		$sc{lc($channel)}{users}{$_}{halfop}	= 1 if $halfop;
		$sc{lc($channel)}{users}{$_}{voice}	= 1 if $voice;
		$sc{lc($channel)}{users}{$_}{owner}	= 1 if $owner;
	}
}

sub irc_userhost {
	my ($text, $host) = @_;

	if ($host) {
		foreach my $chan (keys %sc) {
			if ($sc{$chan}{users}{$text}) {
				$sc{$chan}{users}{$text}{host} = $host;
			}
		}

		return;
	}

	my @users  = split(/ /, $text);
	my $isoper = 0;

	foreach my $user (@users) {
		my ($nick, $host) = split(/\=/, $user);
		if ($nick =~ /\*/) {
			$isoper = 1;
			$nick   =~ s/\*//;
		}
		$host =~ s/\+//;

		foreach my $chan (keys %sc) {
			if ($sc{$chan}{users}{$nick}) {
				$sc{$chan}{users}{$nick}{host} = $host;

				if ($isoper) {
					$sc{$chan}{users}{$nick}{oper} = 1;
				}
			}
		}
		$isoper = 0;
	}
}

sub irc_topic {
	my ($remotenick, $channel, $text, $hostmask) = @_;

	$sc{lc($channel)}{topic}{text}		= $text;
	$sc{lc($channel)}{topic}{'time'}	= time;
	$sc{lc($channel)}{topic}{by}		= $remotenick;

	handle_handler('event', 'topic', $remotenick, $hostmask, $channel, $text);
}

sub irc_join {
	my ($channel, $remotenick, $hostmask) = @_;

	# if it is ourself then we create a record for the channel and update our host
	if ($remotenick eq $nick) {
		$sc{lc($channel)}	= {};
		$myhost			= $hostmask;
		handle_handler('event', 'join_me', $remotenick, $hostmask, $channel);
	}


	irc_raw(1, "whois $remotenick");
	$sc{lc($channel)}{users}{$remotenick}		= {};
	$sc{lc($channel)}{users}{$remotenick}{hostmask}	= $hostmask;

	return if $remotenick eq $nick;
	handle_handler('event', 'join', $remotenick, $hostmask, $channel);
}

sub irc_part {
	my ($channel, $remotenick, $hostmask, $text) = @_;

	# if it is ourself then we delete the channel record
	if ($remotenick eq $nick) {
		delete($sc{lc($channel)});
		handle_handler('event', 'part_me', $remotenick, $hostmask, $channel, $text);
	} else {
		delete($sc{lc($channel)}{users}{$remotenick});
		handle_handler('event', 'part', $remotenick, $hostmask, $channel, $text);
	}
}

sub irc_quit {
	my ($remotenick, $hostmask, $text) = @_;

	my @channels;
	for (keys(%sc)) {
		if (delete($sc{$_}{users}{$remotenick})) {
			push(@channels, $_);
		}
	}

	handle_handler('event', 'quit', $remotenick, $hostmask, $text, @channels);
}

sub irc_nick {
	my ($remotenick, $newnick, $hostmask) = @_;

	if (lc($remotenick) eq lc($nick)) {
		$nick = $newnick;
		handle_handler('event', 'nick_me', $remotenick, $hostmask, $newnick);
		return;
	}

	my @channels;
	for (keys (%sc)) {
		if (defined $sc{$_}{users}{$remotenick}) {
			$sc{$_}{users}{$newnick} = $sc{$_}{users}{$remotenick};
			delete $sc{$_}{users}{$remotenick};
			push(@channels, $_);
		}
	}

	if (defined $sf{$remotenick}) {
		$sf{$newnick} = $sf{$remotenick};
	}

	handle_handler('event', 'nick', $remotenick, $hostmask, $newnick, @channels);
}

sub irc_mode {
	my @mode = split(/ /, $_[0]);

	my ($remotenick, $hostmask) = ($_[1], $_[2]);
	return if $mode[0] !~ /^[#&!@%+~]/;
	return if !defined $mode[0];

	my $channel		= $mode[0];

	shift @mode;
	my ($action)		= substr($mode[0], 0, 1);

	handle_handler('event', 'mode', $remotenick, $hostmask, $channel, $action, @mode);

	my $count	= 0;
	my $i		= 0;
	my $l		= length($mode[0]);

	while ($i <= $l) {
		my $bit = substr($mode[0], $i, 1);


		if ($bit eq "+" || $bit eq "-") {
		  $action = $bit;
		}
		elsif ($bit eq "v") {
		  $count++;
		  my $item = $mode[$count];
		  if ($item eq $nick) {
		    $sc{lc($channel)}{users}{$nick}{voice} = 1 if $action eq "+";
		    $sc{lc($channel)}{users}{$nick}{voice} = undef if $action eq "-";
		    handle_handler('event', 'voice_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  $sc{lc($channel)}{users}{$item}{voice} = 1 if $action eq "+";
		  $sc{lc($channel)}{users}{$item}{voice} = undef if $action eq "-";
		  handle_handler('mode', 'voice', $remotenick, $hostmask, $channel, $action, $item);
		}
		elsif ($bit eq "h") {
		  $count++;
		  my $item = $mode[$count];
		  if ($item eq $nick) {
		    $sc{lc($channel)}{users}{$nick}{halfop} = 1 if $action eq "+";
		    $sc{lc($channel)}{users}{$nick}{halfop} = undef if $action eq "-";
		    handle_handler('event', 'halfop_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  $sc{lc($channel)}{users}{$item}{halfop} = 1 if $action eq "+";
		  $sc{lc($channel)}{users}{$item}{halfop} = undef if $action eq "-";
		  handle_handler('mode', 'halfop', $remotenick, $hostmask, $channel, $action, $item);
		}
		elsif ($bit eq "o") {
		  $count++;
		  my $item = $mode[$count];
		  if ($item eq $nick) {
		    $sc{lc($channel)}{users}{$nick}{op} = 1 if $action eq "+";
		    $sc{lc($channel)}{users}{$nick}{op} = undef if $action eq "-";
		    handle_handler('event', 'op_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  $sc{lc($channel)}{users}{$item}{op} = 1 if $action eq "+";
		  $sc{lc($channel)}{users}{$item}{op} = undef if $action eq "-";
		  handle_handler('mode', 'op', $remotenick, $hostmask, $channel, $action, $item);
		}
		elsif ($bit eq "a") {
		  $count++;
		  my $item = $mode[$count];
		  if ($item eq $nick) {
		    $sc{lc($channel)}{users}{$nick}{protect} = 1 if $action eq "+";
		    $sc{lc($channel)}{users}{$nick}{protect} = undef if $action eq "-";
		    handle_handler('event', 'protect_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  $sc{lc($channel)}{users}{$item}{protect} = 1 if $action eq "+";
		  $sc{lc($channel)}{users}{$item}{protect} = undef if $action eq "-";
		  handle_handler('mode', 'protect', $remotenick, $hostmask, $channel, $action, $item);
		}
		elsif ($bit eq "q") {
		  $count++;
		  my $item = $mode[$count];
		  if ($item eq $nick) {
		    $sc{lc($channel)}{users}{$nick}{owner} = 1 if $action eq "+";
		    $sc{lc($channel)}{users}{$nick}{owner} = undef if $action eq "-";
		    handle_handler('event', 'owner_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  $sc{lc($channel)}{users}{$item}{owner} = 1 if $action eq "+";
		  $sc{lc($channel)}{users}{$item}{owner} = undef if $action eq "-";
		  handle_handler('event', 'owner', $remotenick, $hostmask, $channel, $action, $item);
		}
		elsif ($bit eq "b") {
		  $count++;
		  my $item = $mode[$count];

		  if ($item eq $nick) {
		    handle_handler('event', 'ban_me', $remotenick, $hostmask, $channel, $action);
		    return;
		  }
		  handle_handler('mode', 'ban', $remotenick, $hostmask, $channel, $action);
		}
		elsif ($bit =~ /^[lkIe]/) {
		  $count++;
		  handle_handler('mode', 'otherp', $remotenick, $hostmask, $channel, $action, $bit, $mode[$count]);
		} else {
		  handle_handler('mode', 'other', $remotenick, $hostmask, $channel, $action, $bit);
		}

		$i++;
	}
}

sub irc_msg_handler {
	my ($remotenick, $msgchan, $text, $hostmask) = @_;

	return if ignore($remotenick, $hostmask);

	if ($text =~ /^\001(\w*)( (.*)|)\001$/) {
		irc_ctcp_handler($msgchan, $remotenick, $1, $2, $hostmask);
	} else {
		if ($msgchan !~ /^[#&!+]/) {
			irc_privmsg_handler($remotenick, $text, $hostmask);
		} else {

			irc_channel_handler($remotenick, $msgchan, $text, $hostmask);
		}
	}
}

sub irc_channel_handler {
	my @tmp;
	my ($remotenick, $channel, $text, $hostmask) = @_;
	if ($text =~ /^\Q$options{irc}{cmdprefix}\E(\S+)(\s+(.*))?/) {
		handle_handler('chancmd', $1, $remotenick, $hostmask, $channel, $3);
	}
	elsif ($text =~ /^\Q$nick\E\002?[:,\.]\002?\s+(\S+)(\s+(.*))?/) {
		@tmp = ($1 || "", $3 || "");
		if (!handle_handler('chanmecmd', lc($tmp[0]), $remotenick, $hostmask, $channel, $tmp[1])) {
			handle_handler('chanmecmd', 'default', $remotenick, $hostmask, $channel,
				       $tmp[0].($tmp[1] ne "" ? " ".$tmp[1] : ''));
		}
	}
	elsif (!$options{config}{requiresep} && $text =~ /^\Q$nick\E\s+(\S+)(\s+(.*))?/) {
		@tmp = ($1 || "", $3 || "");
		if (!handle_handler('chanmecmd', $tmp[0], $remotenick, $hostmask, $channel, $tmp[1])) {
			handle_handler('chanmecmd', 'default', $remotenick, $hostmask, $channel, $tmp[0]." ".$tmp[1]);
		}
	}
	handle_handler('message', 'channel', $remotenick, $hostmask, $channel, $text);
}

sub irc_privmsg_handler {
	my ($remotenick, $text, $hostmask) = @_;
	handle_handler('message', 'private', $remotenick, $hostmask, $text);

	my ($command, $options) = split(/ /, $text, 2);
	if (!handle_handler('privcmd', $command, $remotenick, $hostmask, (defined($options) ? $options : ''))) {
		handle_handler('privcmd', 'default', $remotenick, $hostmask, $command." ".(defined $options ? $options : ''));
	}
}

sub irc_ctcp_handler {
	my ($msgchan, $remotenick, $ctcp_command, $ctcp_params, $hostmask) = @_;
	if (handle_handler('ctcp', lc($ctcp_command), $remotenick, $msgchan, $ctcp_params)) {
		return;
	}

	if ($ctcp_command eq "VERSION") {
		return if flood_check($remotenick, $hostmask, 'ctcp', 30, 3);
		irc_ctcp_reply($remotenick, 'VERSION', "I am $options{config}{version} running on Perl version: $^V.");
	}
	if ($ctcp_command eq "TIME") {
		return if flood_check($remotenick, $hostmask, 'ctcp', 30, 3);
		my $ttime = localtime;
		irc_ctcp_reply($remotenick, 'TIME', $ttime);
	}
	if ($ctcp_command eq "PING") {
		return if flood_check($remotenick, $hostmask, 'ctcp', 30, 3);
		irc_ctcp_reply($remotenick, 'PING', $ctcp_params);
	}
	if ($ctcp_command eq "FINGER") {
		return if flood_check($remotenick, $hostmask, 'ctcp', 30, 3);
		irc_ctcp_reply($remotenick, 'FINGER', "~UNF~!!!!");
	}
}

sub irc_notice {
	my ($remotenick, $text, $hostmask, $msgchan) = @_;

	return if $remotenick eq $cfg->{Shadow}->{IRC}->{bot}->{nick} && $text eq 'anti-reconnect';
	handle_handler('event', 'notice', $remotenick, $hostmask, $msgchan, $text);
}

sub irc_invite {
	my ($remotenick, $channel) = @_;

	handle_handler('event', 'invite', $remotenick, $channel);
}

sub irc_kick {
	my ($remotenick, $channel, $knick, $text, $hostname) = @_;

	delete($sc{lc($channel)}{users}{$knick});
	handle_handler('event', 'kick', $remotenick, $channel, $knick, $text, $hostname);
}

sub irc_raw {
	handle_handler('raw', 'out', $_[1], $_[0]);
	push(@{$queue[$_[0]]}, $_[1]."\n");
}

sub irc_say {
	my ($target, $text, $level) = @_;

	$level = 2 if !defined $level;

	if ($target =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/gm) {
		$WebAdmin::outbuf{$WebAdmin::sockmap{$target}} .= formatTerm($text);
	} else {
		irc_raw($level, "PRIVMSG $target :$text");
	}
}


sub irc_knock {
	return;
}

# IRC Command routines for modules

sub connected {
    my $self = shift;

    return $connected;
}


sub say {
	my $self = shift;
	irc_say(@_);
}


sub ctcp {
	my $self = shift;
	irc_ctcp(@_);
}

sub formatTerm {
	my $text = shift;

	my %colors = (
		0  => "#FFFFFF",
		1  => "#000000",
		2  => "#00007F",
		3  => "#009300",
		4  => "#FF0000",
		5  => "#7F0000",
		6  => "#9C009C",
		7  => "#FC7F00",
		8  => "#FFFF00",
		9  => "#00FC00",
		10 => "#009393",
		11 => "#00FFFF",
		12 => "#0000FC",
		13 => "#FF00FF",
		14 => "#7F7F7F",
		15 => "#D2D2D2"
	);

	$text = "$text\r\n";

	return $text;
}

sub fastout {
	my ($self, $out) = @_;

	sendfh($irc, $out);

	foreach my $fh ($sel->can_write(0)) {
		flush_out($fh);
	}
}

sub fastnotice {
	my $self = shift;
	my ($nick, @raw) = @_;

	my $level = 0;

	if ($nick =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) {
		foreach my $text (@raw) {
			$WebAdmin::outbuf{$WebAdmin::sockmap{$nick}} .= formatTerm($text);
		}
		return;
	}

	my $out = "";
	my $tmpl = "NOTICE $nick :";
	my $i = 0;

	while (1) {		
		if ($i >= scalar(@raw)) {
			$self->fastout($out);

			last;
		}

		chomp $raw[$i];
		my $nextline = $tmpl.$raw[$i]."\r\n";
		my $outlen   = length($out);
		my $newoutlen = $outlen + length($nextline);

		if ($newoutlen > 510) {
			$self->fastout($out);

			$level++;
			$out = "";
		} else {
			$out .= $nextline;
			$i++;
		}
	}
}

sub fastsay {
	my $self = shift;
	my ($nick, @raw) = @_;

	my $level = 0;

	if ($nick =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) {
		foreach my $text (@raw) {
			$WebAdmin::outbuf{$WebAdmin::sockmap{$nick}} .= formatTerm($text);
		}
		return;
	}

	my $out = "";
	my $tmpl = "PRIVMSG $nick :";
	my $i = 0;

	while (1) {		
		if ($i >= scalar(@raw)) {
			$self->fastout($out);
			
			last;
		}

		chomp $raw[$i];
		my $nextline = $tmpl.$raw[$i]."\r\n";
		my $outlen   = length($out);
		my $newoutlen = $outlen + length($nextline);

		if ($newoutlen > 510) {
			$self->fastout($out);

			$level++;
			$out = "";
		} else {
			$out .= $nextline;
			$i++;
		}
	}
}

sub notice {
	my $self = shift;
	my ($target, $text, $level) = @_;

	$level = 2 if !$level;

	if ($target =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) {
		$WebAdmin::outbuf{$WebAdmin::sockmap{$target}} .= formatTerm($text);
	} else {
		irc_raw($level, "NOTICE $target :$text");
	}
}

sub emote {
	my $self = shift;
	my ($target, $text, $level) = @_;
	$level = 2 if !$level;
	irc_ctcp($target, "ACTION", $text, $level);
}

sub nick {
	my $self = shift;
	return $nick if !$_[0];
	$nick = $_[0];		# for some reason we didn't do this before
	irc_raw(1, "NICK $_[0]");
}

sub join {
	my $self = shift;
	irc_raw(1, scalar(@_) > 1 ? "JOIN $_[0] :$_[1]" : "JOIN $_[0]");
}

sub part {
	my $self = shift;
	irc_raw(1, scalar(@_) > 1 ? "PART $_[0] :$_[1]" : "PART $_[0]");
}

sub kick {
	my $self = shift;
	irc_raw(1, "KICK $_[0] $_[1] :$_[2]");
}

sub mode {
	my $self = shift;
	irc_raw(1, "MODE ". CORE::join(" ", @_));
}

sub voice {
	my $self = shift;
	irc_raw(1, "MODE $_[0] +v :$_[1]");
}

sub devoice {
	my $self = shift;
	irc_raw(1, "MODE $_[0] -v :$_[1]");
}

sub halfop {
	my $self = shift;
	irc_raw(1, "MODE $_[0] +h :$_[1]");
}

sub dehalfop {
	my $self = shift;
	irc_raw(1, "MODE $_[0] -h :$_[1]");
}

sub op {
	my $self = shift;
	irc_raw(1, "MODE $_[0] +o :$_[1]");
}

sub deop {
	my $self = shift;
	irc_raw(1, "MODE $_[0] -o :$_[1]");
}

sub raw {
	my $self = shift;
	irc_raw($_[1] || 1, "$_[0]");
}

sub listusers {
	my ($self, $channel) = @_;
	my %tmp;
	$tmp{$_} = 1 for (keys(%{$sc{lc($channel)}{users}}));
	delete($tmp{$nick});
	delete($tmp{lc($nick)});
	return keys %tmp;
}

 sub listusers_async {
	 my ($self, $channel, $cb) = @_;

	 my %tmp;
	 $tmp{$_} = 1 for (keys(%{$sc{lc($channel)}{users}}));
	 delete($tmp{$nick});
	 delete($tmp{lc($nick)});

	 &{$cb}($channel, keys %tmp);
 }

sub gethost {
	my ($self, $nick) = @_;

	foreach my $chan (keys %sc) {
		if (exists($sc{$chan}{users}{$nick}{host})) {
			return $sc{$chan}{users}{$nick}{host};
		}
	}
}

sub flood {
	my $self = shift;
	return flood_check(@_);
}

sub reconnect {
	my $self = shift;
	irc_reconnect();
}

sub isowner {
	my ($self, $nick, $channel) = @_;
	if (defined($sc{lc($channel)}{users}{$nick}{owner})) {
		return 1;
	} else {
		return 0;
	}
}

sub isprotect {
	my ($self, $nick, $channel) = @_;
	if (defined($sc{lc($channel)}{users}{$nick}{protect})) {
		return 1;
	} else {
		return 0;
	}
}

sub isop {
	my ($self, $nick, $channel) = @_;
	if ($nick =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) {
		return 1;
	}

	if (defined($sc{lc($channel)}{users}{$nick}{op}))
	{
		return 1;
	} else {
		return 0;
	}
}

sub ishop {
	my ($self, $nick, $channel) = @_;
	if (defined($sc{lc($channel)}{users}{$nick}{halfop})) {
		return 1;
	} else {
		return 0;
	}
}

sub isvoice {
	my ($self, $nick, $channel) = @_;
	if (defined($sc{lc($channel)}{users}{$nick}{voice})) {
		return 1;
	} else {
		return 0;
	}
}

sub check_admin {
  my ($nick, $host) = @_;

  my @tmp = @{$cfg->{Shadow}->{Admin}->{bot}->{admins}};

  foreach my $t (@tmp) {
    my ($u, $h) = split(/\!/, $t);

    if ($u eq $nick || $u eq "*") {
      my ($ar, $ahm) = split(/\@/, $host);
      my ($r, $hm) = split(/\@/, $h);

      if ($r eq "*" && $hm ne "*") {
        return 1 if $hm eq $ahm;
      }
      elsif ($r ne "*" && $hm eq "*") {
        return 1 if $r eq $ar;
      }
      elsif ($r eq "*" && $hm eq "*") {
        return 1 if $u eq $nick;
      } else {
        return 1 if $r eq $ar && $hm eq $ahm;
      }
    }
  }

  return 0;
}

sub color {
	my ($self, $fg, $bg) = @_;
	my %colors = (
		'white'      => 0,
		'black'      => 1,
		'blue'       => 2,
		'green'      => 3,
		'lightred'   => 4,
		'brown'      => 5,
		'purple'     => 6,
		'orange'     => 7,
		'yellow'     => 8,
		'lightgreen' => 9,
		'cyan'       => 10,
		'lightcyan'  => 11,
		'lightblue'  => 12,
		'pink'       => 13,
		'gray'       => 14,
		'lightgray'  => 15
	);
	my $colorstr = "\003";

	if ($fg) {
		$colorstr = $colorstr.$colors{$fg};
	}

	if ($bg) {
		$colorstr = $colorstr.",".$colors{$bg};
	}

	return $colorstr;
}

sub bold {
	my ($self) = @_;

	return "\002";
}

sub isbotadmin {
	my ($self, $nick, $host) = @_;

	if ($nick =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/ && $host eq "-TERM-") {
		return 1;
	}

	return check_admin($nick, $host);
}

sub isin {
	my ($self, $channel, $nick) = @_;
	if (defined($sc{lc($channel)}{users}{$nick})) {
		return 1;
	} else {
		return 0;
	}
}

sub topic {
	my ($self, $channel, $topic) = @_;
	if (!defined($topic)) {
		return $sc{lc($channel)}{topic}{text};
	} else {
		irc_raw(2, "TOPIC $channel :$topic");
	}
}

sub irc_sayfh {
	my ($target, $text) = @_;
	syswrite($irc, "PRIVMSG $target :$text\r\n", length("PRIVMSG $target :$text\r\n"));
}

sub irc_ctcp {
	my ($target, $type, $text, $level) = @_;
	if (!defined($level)) {
		$level = 2;
	}
	irc_raw($level, "PRIVMSG $target :\001$type $text\001");
}

sub irc_ctcp_reply {
	my ($target, $type, $text, $level) = @_;

	irc_send_notice($target, "$type $text", $level);
}

sub irc_send_notice {
	my ($target, $text, $level) = @_;
	if (!defined($level)) {
		$level = 2;
	}
	irc_raw($level, "NOTICE $target :$text");
}

sub check_host {
	my ($self, $mask, $host) = @_;
	$mask  = quotemeta($mask);
	$mask  =~ s/\\\*/.*/g;
	$mask  =~ s/\\\?/./g;
	if ($host =~ /^$mask$/i) {
		return;
	}
	return 0;
}

# Flood Checking Stuff

sub flood_add {
	my ($nick, $hostmask, $text) = @_;
	$hostmask =~ s/^(.*?\!)?.*?\@//;
	push(@{$sf{$hostmask}{$nick}{$text}}, time);
}

sub flood_process {
	my ($host, $rnick, $type);
	my ($time) =  time;
	for $host (keys %sf) {
		for $rnick (keys %{$sf{$host}}) {
			for $type (keys %{$sf{$host}{$rnick}}) {
				next if (!defined($sf{$host}{$rnick}{$type}[0]));
				while ($time >= $sf{$host}{$rnick}{$type}[0] + $options{flood}{time}) {
					last if ($#{$sf{$host}{$rnick}{$type}} == 0);
					shift(@{$sf{$host}{$rnick}{$type}});
				}
			}
		}
	}
}

sub flood_check_type {
	my ($rnick, $hostmask, $type) = @_;
	$hostmask =~ s/^(.*?\!)?.*?\@//;
	return ($#{$sf{$hostmask}{$rnick}{$type}},
		flood_check_burst($sf{$hostmask}{$rnick}{$type}));
}

sub flood_check_nick {
	my ($rnick, $hostmask) = @_;
	$hostmask =~ s/^(.*?\!)?.*?\@//;
	my ($tmp, $tmpb);
	for my $type (keys %{$sf{$hostmask}{$rnick}}) {
		$tmp += $#{$sf{$hostmask}{$rnick}{$type}};
		$tmpb += flood_check_burst($sf{$hostmask}{$rnick}{$type});
	}
	return ($tmp, $tmpb);
}

sub flood_check_host {
	my ($hostmask) = @_;
	$hostmask =~ s/^(.*?\!)?.*?\@//;
	my ($tmp, $tmpb);
	for my $rnick (keys %{$sf{$hostmask}}) {
		for my $type (keys %{$sf{$hostmask}{$rnick}}) {
			$tmp += $#{$sf{$hostmask}{$rnick}{$type}};
			$tmpb += flood_check_burst($sf{$hostmask}{$rnick}{$type});
		}
	}
	return ($tmp, $tmpb);
}

sub flood_check_all {
	my ($tmp, $tmpb, $hostmask, $rnick, $type);
	for $hostmask (keys %sf) {
		for $rnick (keys %{$sf{$hostmask}}) {
			for $type (keys %{$sf{$hostmask}{$rnick}}) {
				$tmp += $#{$sf{$hostmask}{$rnick}{$type}};
				$tmpb += flood_check_burst($sf{$hostmask}{$rnick}{$type});
			}
		}
	}
	return ($tmp, $tmpb);
}

sub flood_check_burst {
	my $ref = shift;
	my $time = time - $options{flood}{btime};
	my $tmp;
	for (@$ref) {
		$tmp++ if ($_ >= $time);
	}
	return $tmp;
}

sub flood_do {
	my ($remotenick, $hostmask, $num, $bnum, $limit, $blimit, $ftype, $itype) = @_;
	if (defined($bnum) && $bnum >= $blimit) {
		logger(2, 'flood', "$ftype burst flood deleted $remotenick ($hostmask) using $itype"),
			 if ($bnum == $blimit);
		if ($bnum >= $blimit + 3) {
			if ($ftype ne "all") {
				logger(2, "autoignoring $remotenick ($hostmask) for 1 minute");
				#$options{ignore}{irc_makebanmask($hostmask, 'host')} = time + 60;
				$options{ignore}{$hostmask} = time + 60;
			} else {
				logger(2, "autoignoring all for 15 seconds (triggered by $remotenick)");
				$options{ignore}{'*!*@*'} = time + 15;
			}
		}
		handle_handler('event', 'flood', $remotenick, $hostmask, $num, $bnum, $limit, $blimit, $ftype, $itype);
		return 1;
	}
	elsif (defined $num && $num >= $limit) {
		logger(2, 'flood', "$ftype flood detected from $remotenick ($hostmask) using $itype"),
			if ($num == $limit);
		if ($num >= $limit + 3) {
			if ($ftype ne "all") {
				logger(2, "autoignoring $remotenick ($hostmask) for 5 minutes");
				#$options{ignore}{irc_makebanmask($hostmask, 'host')} = time + 300;
				$options{ignore}{$hostmask} = time + 300;
			} else {
				logger(2, "autoignoring all for 30 seconds (triggered by $remotenick)");
				$options{ignore}{'*!*@*'} = time + 30;
			}
		}
		handle_handler('event', 'flood', $remotenick, $hostmask, $num, $bnum, $limit, $blimit, $ftype, $itype);
		return 1;
	}
}

sub flood_check {
	my ($remotenick, $hostmask, $type, $time, $num) = @_;
	return 'igonore' if (ignore($remotenick, $hostmask));
	flood_add($remotenick, $hostmask, $type);

	flood_do();

	my ($floodtype, $floodtypeburst) = flood_check_type($remotenick, $hostmask, $type);
	return 'type' if (flood_do($remotenick, $hostmask, $floodtype, $floodtypeburst, $options{flood}{typenum},
				$options{flood}{typebnum}, 'type', $type));
	my ($floodnick, $floodnickburst) = flood_check_nick($remotenick, $hostmask, $type);
	return 'nick' if (flood_do($remotenick, $hostmask, $floodnick, $floodnickburst, $options{flood}{typenum},
				$options{flood}{typebnum}, 'nick', $type));
	my ($floodhost, $floodhostburst) = flood_check_host($remotenick, $hostmask, $type);
	return 'host' if (flood_do($remotenick, $hostmask, $floodhost, $floodhostburst, $options{flood}{typenum},
				$options{flood}{typebnum}, 'host', $type));
	my ($floodall, $floodallburst) = flood_check_all();
	return 'all' if (flood_do($remotenick, $hostmask, $floodall, $floodallburst, $options{flood}{typenum},
				$options{flood}{typebnum}, 'all', $type));
	return;
}

sub ignore {
	my ($remotenick, $hostmask) = @_;
	my $time = time;
	for (keys %{$options{ignore}}) {
		if ($options{ignore}{$_} > 2 && $options{ignore}{$_} < $time) {
			Shadow::Core::log(1, "Removing ignore for $remotenick [$hostmask]", "System");
			delete($options{ignore}{$_});
			next;
		}
		return 1 if (lc($_) eq lc($remotenick));
		return 1 if (/\!/ && check_host($_, $hostmask));
	}
	return 0;
}

sub logger {
	my ($level, $class, $text) = @_;
	handle_handler('event', 'log', $level, $class, $text);

	Shadow::Core::log(1, "[$level:$class] $text", "System");
	return 1;
}

sub add_ignore {
	my ($self, $remotenick, $hostmask) = @_;

	Shadow::Core::log(1, "Ignoring $remotenick [$hostmask]", "System");

	$options{ignore}{$hostmask} = 1;
	$options{ignore}{$remotenick} = 1;
}

sub del_ignore {
	my ($self, $remotenick, $hostmask) = @_;

	Shadow::Core::log(1, "Unignoring $remotenick [$hostmask]", "System");

	delete $options{ignore}{$hostmask} if exists $options{ignore}{$hostmask};
	delete $options{ignore}{$remotenick} if exists $options{ignore}{$remotenick};
}

sub add_handler {
	my ($self, $event, $sub) = @_;
	my $caller = caller();
	my @event  = split(/ /, $event);
	if ($event[0] eq "raw") {
		add_handler_parsed('raw', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq "ctcp") {
		add_handler_parsed('ctcp', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'message') {
		add_handler_parsed('message', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'mode') {
		add_handler_parsed('mode', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'event') {
		add_handler_parsed('event', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'chanmecmd') {
		add_handler_parsed('chanmecmd', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'chancmd') {
		add_handler_parsed('chancmd', $event[1], $caller, $sub);
		#print "added chancmd handler: $event[1], $caller, $sub\n" if $debug;
	}
	elsif ($event[0] eq 'privcmd') {
		add_handler_parsed('privcmd', $event[1], $caller, $sub);
	}
	elsif ($event[0] eq 'module') {
		add_handler_parsed('module', $event[1], $caller, $sub);
	} else {
		return 0;
	}
}

sub add_handler_parsed {
	my ($handler, $subhandler, $caller, $sub) = @_;
	push(@{$handlers{$handler}{$subhandler}},
		{
			'module' => $caller,
			'sub'    => $sub,
		}
	);
}

sub handle_handler {
	my ($handler, $subhandler, @messages) = @_;
	return 0 if (!defined($handlers{$handler}{$subhandler}));

	for (@{$handlers{$handler}{$subhandler}}) {
		my ($module, $sub) = ($_->{module}, $_->{sub});

		eval("${module}::$sub(\@messages);");
		if ($@) {
			err(1, "[Core/handle_handler] eval sytanx error: $@\ncode: $module :: $sub\(@messages\)", 0, "System");
        }
	}
	return 1;
}

sub handle_term_privcmd {
	my ($self, $client, $cmd, $args) = @_;

	handle_handler('privcmd', $cmd, '-TERM-', $client, $args);

}

sub del_handler {
	my ($self, $event, $sub) = @_;
	my @event = split(/ /, $event);
	if ($handlers{$event[0]}{$event[1]}) {
		my $count = 0;
		for (@{$handlers{$event[0]}{$event[1]}}) {
			if ($_->{sub} eq $sub) {
				splice(@{$handlers{$event[0]}{$event[1]}}, $count, 1);
				#delete($handlers{$event[0]}{$event[1]});
			} else {
				$count++;
			}
		}
	}
}

sub add_timeout {
	my ($self, $timeout, $sub) = @_;

	my $caller = caller();
	push(@timeout,
		{
			'time'		=> time + $timeout,
			'module' 	=> $caller,
			'sub'		=> $sub,
		}
	);
}

sub is_term_user {
    my ($self, $usr) = @_;

	if ($usr =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/) {
        return 1;
    }

    return 0;
}

1;
