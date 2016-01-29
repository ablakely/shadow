# Shadow::Core	- Core Module for Shadow IRC Bot
# Written by Aaron Blakely <aaron@ephasic.org>
# Supports:
#	/Most/ IRCd's - Since it scans 005 of the PREFIXES

package Shadow::Core;

use v5.10;
use Carp;
use strict;
use warnings;
use IO::Select;
use IO::Socket::INET;
use Sub::Delete;

# Global Variables, Arrays, and Hashes
our ($sel, $ircping, $checktime, $irc, $nick, $lastout, $myhost, $time);
our (@queue, @timeout, @loaded_modules, @onlineusers);
our (%server, %options, %handlers, %sc, %su, %sf, %inbuffer, %outbuffer, %users);

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
		version		=> 'Shadow v0.08 - By Aaron Blakely (Dark_Aaron)',
		userdb		=> 'users',
	},
	irc => {
		q_prefix	=> '~',
		a_prefix	=> '!',
		o_prefix	=> '@',
		h_prefix	=> '%',
		v_prefix	=> '+',
		cmdprefix	=> '.',
	},
		
);

# Constructor
sub new {
	my $class				= shift;
	my $self				= {};
	my ($servers, $nick, $name, $verbose)	= @_;
	my @serverlist				= split(/,/, $servers);

	foreach my $ircserver (@serverlist) {
		my ($serverhost, $serverport)	= split(/:/, $ircserver);
		$server{$serverhost}		= {};
		$server{$serverhost}{port}	= $serverport || 6667;
	}
	
	# generate a alternative nickname from the account thats executing the bot if no nick is defined
	# Example: the user is named 'aaron', then the bot will be named 'aaronbot'
	my $whoami = `whoami`;
	chomp $whoami;
	$whoami .= "bot";
	$options{config}{nick}		= $nick || $whoami;
	$options{config}{name}		= $name || $nick;
	$options{config}{reconnect}	= 200;
	
	# to put something in there
	$Shadow::Core::nick = $nick;
	
	# Push the loaded modules into our array
	foreach my $modname (sort keys %INC) {
		$modname				=~ s/\//\:\:/gs;	# replace / with ::
		$modname				=~ s/\.pm$//;		# remove the .pm		
		$loaded_modules[++$#loaded_modules] 	= $modname;
	}
	
	if (!$verbose) {
		open (STDOUT, ">./shadow.log") or die $!;
		open (STDERR, ">./shadow.log") or die $!;
	}
	
	return bless($self, $class);
}

# We'll handle our module stuff here

sub shadowuse {
	my $self = shift;
	my ($mod) = @_;
	my $caller = caller;

	eval "package $caller; use $mod;";
	$loaded_modules[++$#loaded_modules] = $mod;
}


sub load_module {
	my ($self, $module_name) = @_;
	
	if (-e "modules/$module_name\.pm") {
		print "Loading module: $module_name\n";
		package main;				# switch to the main package
		require "modules/$module_name\.pm";	# require the module from the 'main' package
		eval "package main::$module_name; loader();";
		package Shadow::Core;
		$loaded_modules[++$#loaded_modules] = "Shadow::Mods::".$module_name;
		handle_handler('module', 'load', $module_name);
		return 1;
	} else {
		print "Error: No such module $module_name\n";
		return undef;
	}
}

sub unload_module {
	my ($self, $module_name) = @_;
	
	foreach my $loaded_mod (@loaded_modules) {
		if ($loaded_mod eq $module_name) {
			eval "package main::$module_name; unloader();";
			package Shadow::Core;
			return 1;
		}
	}
	
	return undef;
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
			irc_raw(3, "NOTICE $nick :anti-reconnect");	# to try and keep us alive
		}

		irc_reconnect() if ($ircping + $options{config}{reconnect} <= $time);
		
		for (@timeout) {
			if (defined($_->{'time'}) && $time >= $_->{'time'}) {
				delete($_->{'time'});
				my ($module, $sub) = ($_->{module}, $_->{'sub'});
				eval("${$module}::$sub();");
			}
		}
	}
}

# IRC processing and events

sub irc_connect {
	my ($ircserver, $ircport) = split(/:/, $_[0], 2);
	
	print "Connecting to IRC server... [server=$ircserver, port=$ircport]\n";
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
	
	if ($response =~ /^PING (.*)$/) {
		irc_raw(0, "PONG $1");
	}
	elsif ($response =~ /^NOTICE/) {
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
		
		given ($bits[1]) {
			when (/004/) {
				# connected event
				irc_connected($bits[2]);
			}
			when (/005/) {
				# scan 005 info for adapting to our enviornment
				irc_scaninfo(@bits);
			}
			when (/433/) {
				# nickname is use event
				irc_nicktaken($bits[3]);
			}
			when (/353/) {
				# NAMES event
				irc_users($bits[4], split(/ /, $text));
			}
			when (/MODE/) {
				# MODE event
				my $mode = join(" ", @bits[2 .. scalar(@bits) - 1]) if defined $bits[2];
				$mode .= $text if defined $text;
				irc_mode($mode, $remotenick, $bits[0]);
			}
			when (/PRIVMSG/) {
				# PRIVMSG event
				irc_msg_handler($remotenick, $bits[2], $text, $bits[0]);
			}
			when (/JOIN/) {
				# JOIN event
				irc_join($text, $remotenick, $bits[0]);
			}
			when (/PART/) {
				# PART event
				irc_part($bits[2], $remotenick, $bits[0], $text);
			}
			when (/QUIT/) {
				# QUIT event
				irc_quit($remotenick, $bits[0], $text);
			}
			when (/NOTICE/) {
				# NOTICE event
				irc_notice($remotenick, $bits[2], $text, $bits[0]);
			}
			when (/NICK/) {
				# nick change events

				irc_nick($remotenick, $bits[2], $text, $bits[0]);
			}
			when (/INVITE/) {
				# INVITE event
				irc_invite($remotenick, $bits[3], $text, $bits[0]);
			}
			when (/KICK/) {
				# KICK event
				irc_kick($remotenick, $bits[2], $bits[3], $text, $bits[0]);
			}
			when (/[473|475|479]/) {
				# KNOCK event
				irc_knock($remotenick, $bits[3], $text, $bits[0]);
			}
			when (/332/) {
				# TOPIC event
				$sc{lc($bits[3])}{topic}{text} = $text;
			}
			when (/333/) {
				# TOPIC info event
				$sc{lc($bits[3])}{topic}{by}		= $bits[4];
				$sc{lc($bits[3])}{topic}{'time'}	= $bits[5];
			}
			when (/TOPIC/) {
				# TOPIC event
				irc_topic($remotenick, $bits[2], $text, $bits[0]);
			}
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

sub irc_connected {
	$nick = shift;
	mode($nick, "+i");
	handle_handler('event', 'connected', $nick);
}

sub irc_nicktaken {
	my ($taken) = @_;
	
	print "The nick ($nick) is taken: $taken\n";
	if ($taken) {
		print "Appending random chars to the end of the nickname..\n";
		my $tmp = $Shadow::Core::nick . int(rand(9)) . int(rand(9)) . int(rand(9));
		
		irc_raw(0, "NICK $tmp");
		handle_handler('event', 'nicktaken', $nick, $tmp);
		$nick = $tmp;
		irc_nick($tmp);
	}
}

sub irc_users {
	my ($channel, @users) = @_;
	
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
	my ($action)		= substr($mode[0], 0, 1);
	
	handle_handler('event', 'mode', $remotenick, $hostmask, $channel, $action, @mode);
	
	my $count	= 1;
	my $i		= 0;
	my $l		= length($mode[1]) - 1;
	
	while ($i <= $l) {
		my $bit = substr($mode[1], $i, 1);
		
		given ($bit) {
			when (/\+/) {
				$action		= "+";
			}
			when (/\-/) {
				$action		= "-";
			}
			when (/v/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					$sc{lc($channel)}{users}{$nick}{voice} = 1 if $action eq "+";
					$sc{lc($channel)}{users}{$nick}{voice} = undef if $action eq "-";
					
					handle_handler('event', 'voice_me', $remotenick, $hostmask, $channel, $action);
				}
				
				return if $item eq $nick;
				$sc{lc($channel)}{users}{$item}{voice}		= 1 if $action eq "+";
				$sc{lc($channel)}{users}{$item}{voice}		= undef if $action eq "-";
				handle_handler('mode', 'voice', $remotenick, $hostmask, $channel, $action, $item);
			}
			when (/h/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					$sc{lc($channel)}{users}{$nick}{halfop} = 1 if $action eq "+";
					$sc{lc($channel)}{users}{$nick}{halfop} = undef if $action eq "-";
					
					handle_handler('event', 'halfop_me', $remotenick, $hostmask, $channel, $action);
				}
				
				return if $item eq $nick;
				$sc{lc($channel)}{users}{$item}{halfop}		= 1 if $action eq "+";
				$sc{lc($channel)}{users}{$item}{halfop}		= undef if $action eq "-";
				handle_handler('mode', 'halfop', $remotenick, $hostmask, $channel, $action, $item);
			}
			when (/o/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					$sc{lc($channel)}{users}{$nick}{op} = 1 if $action eq "+";
					$sc{lc($channel)}{users}{$nick}{op} = undef if $action eq "-";

					handle_handler('event', 'op_me', $remotenick, $hostmask, $channel, $action);
				}
				
				return if $item eq $nick;
				$sc{lc($channel)}{users}{$item}{op}		= 1 if $action eq "+";
				$sc{lc($channel)}{users}{$item}{op}		= undef if $action eq "-";
				handle_handler('mode', 'op', $remotenick, $hostmask, $channel, $action, $item);
			}
			when (/a/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					$sc{lc($channel)}{users}{$nick}{protect} = 1 if $action eq "+";
					$sc{lc($channel)}{users}{$nick}{protect} = undef if $action eq "-";

					handle_handler('event', 'protect_me', $remotenick, $hostmask, $channel, $action);
				}
				
				return if $item eq $nick;
				$sc{lc($channel)}{users}{$item}{protect}	= 1 if $action eq "+";
				$sc{lc($channel)}{users}{$item}{protect}	= undef if $action eq "-";
				handle_handler('mode', 'protect', $remotenick, $hostmask, $channel, $action, $item);
			}
			when (/q/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					$sc{lc($channel)}{users}{$nick}{owner} = 1 if $action eq "+";
					$sc{lc($channel)}{users}{$nick}{owner} = undef if $action eq "-";

					handle_handler('event', 'owner_me', $remotenick, $hostmask, $channel, $action);
				}
				
				return if $item eq $nick;
				$sc{lc($channel)}{users}{$item}{owner}		= 1 if $action eq "+";
				$sc{lc($channel)}{users}{$item}{owner}		= undef if $action eq "-";
				handle_handler('mode', 'owner', $remotenick, $hostmask, $channel, $action);
			}
			when (/b/) {
				$count++;
				my $item = $mode[$count];
				if ($item eq $nick) {
					handle_handler('event', 'ban_me', $remotenick, $hostmask, $channel, $action);
				}
				return if $item eq $nick;
				handle_handler('mode', 'ban', $remotenick, $hostmask, $channel, $action);
			}
			when (/^[lkIe]$/) {
				$count++;
				handle_handler('mode', 'otherp', $remotenick, $hostmask, $channel, $action, $bit, $mode[$count]);
			}
			default {
				handle_handler('mode', 'other', $remotenick, $hostmask, $channel, $action, $bit);
			}
		}
		$i++;
	}
	1;
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
		irc_ctcp_reply($remotenick, 'VERSION', "I am Shadow v0.05 written by Dark_Aaron running on Perl version: $^V.");
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
	
	return if $remotenick eq $nick and $text eq 'anti-reconnect';
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
	irc_raw($level, "PRIVMSG $target :$text");
}

sub irc_knock {
	return;
}

# IRC Command routines for modules

sub say {
	my $self = shift;
	irc_say(@_);
}


sub ctcp {
	my $self = shift;
	irc_ctcp(@_);
}

sub notice {
	my $self = shift;
	my ($target, $text, $level) = @_;
	
	$level = 2 if !$level;
	irc_raw($level, "NOTICE $target :$text");
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
	irc_raw(1, "JOIN $_[0]");
}

sub part {
	my $self = shift;	
	irc_raw(1, "PART $_[0]");
}

sub kick {
	my $self = shift;
	irc_raw(1, "KICK $_[0] $_[1] $_[2]");
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

sub isin {
	my ($self, $channel, $nick) = @_;
	if (defined($sc{lc($channel)}{$nick})) {
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
	irc_ctcp(@_);
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
				$options{ignore}{irc_makebanmask($hostmask, 'host')} = time + 60;
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
				logger(2, "autoignoring $remotenick ($hostmask) of 5 minutes");
				$options{ignore}{irc_makebanmask($hostmask, 'host')} = time + 300;
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
	return 1;
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
		print "added chancmd handler: $event[1], $caller, $sub\n";
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
	}
	return 1;
}

sub del_handler {
	my ($self, $event, $sub) = @_;
	my @event = split(/ /, $event);
	if ($handlers{$event[0]}{$event[1]}) {
		my $count = 0;
		for (@{$handlers{$event[0]}{$event[1]}}) {
			if ($_->{sub} eq $sub) {
				splice(@{$handlers{$event[0]}{$event[1]}}, $count, 1);
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

1;
