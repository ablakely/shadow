package RadioWebHook;

use JSON;
use IO::Socket::INET;

my $bot = Shadow::Core;
my $help = Shadow::Help;

our $sock;
my $np;
my $announcechan = "#CrackersRadio";


sub loader {
    $sock = IO::Socket::INET->new(
        LocalPort => 5848,
        Protot    => 'tcp',
        Listen    => SOMAXCONN,
        Blocking  => 0,
        Reuse     => 1,
        Timeout   => .1
    ) or return $bot->err("RadioWebHook: Cannot create socket on port 5848.");

    $bot->log("RadioWebHook: HTTP Server started on port 5848.");

    $bot->add_handler('event tick', 'rwh_tick');
    $bot->add_handler('chancmd np', 'rwh_np');
    $bot->add_handler('chancmd listeners', 'rwh_listeners');
}

sub rwh_tick {
    my $oldnp = $np;

    my $client = $sock->accept();
    return unless $client;

    print $client "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n shadow radio web hook httpd\r\n";

    $bot->log("[RadioWebHook] Received HTTP connection from ".$client->peerhost());

    while (my $line = <$client>) {   
        chomp $line; 

        next if ($line =~ /POST \/ HTTP\/1.1/);
        next if ($line =~ /(Host|User\-Agent|Content\-Type|Content\-Length): (.*)/);
        next if ($line =~ /(\s|\n|\r\n|\r)$/);

        $np = from_json($line);

        if ($announcechan && $oldnp->{now_playing}->{song}->{text} ne $np->{now_playing}->{song}->{text}) {
            rwh_np("", "", $announcechan, "");
        }
    }
}

sub rwh_np {
    my ($nick, $host, $chan, $text) = @_;

    if ($text =~ /next/) {
        if ($np->{playing_next}) {
            my $npstr = "\x034[cracker radio]\x03 \x02Playing Next\x02: ".$np->{playing_next}->{song}->{text}." ";
            $npstr .= "\x02Listen now\x02: ".$np->{station}->{public_player_url};
            $bot->say($chan, $npstr);
        }
    } elsif ($text =~ /(prev|previous)/) {
        if ($np->{song_history}) {
            my $npstr = "\x034[cracker radio]\x03 \x02Previously Played\x02: ";
            my @history = @{$np->{song_history}};
            my $cnt = scalar(@history);

            foreach my $song (@history) {
                $npstr .= " \x034\x02$cnt\x02\x03. ".$song->{song}->{text};
                $cnt--;
            }

            $bot->say($chan, $npstr);
        }
    } else {
        if ($np->{now_playing}) {
            my $npstr = "\x034[cracker radio]\x03 \x02Now Playing\x02: ".$np->{now_playing}->{song}->{text}." ";
            $npstr .= "\x02Listen now\x02: ".$np->{station}->{public_player_url};
            $bot->say($chan, $npstr);
        }
    }
}

sub rwh_listeners {
    my ($nick, $host, $chan, $text) = @_;

    if ($np->{listeners}) {
        $bot->say($chan, "\x034[cracker radio]\x03 \x02Current Listeners\x02: ".$np->{listeners}->{current});
    }
}


sub unloader {
    close $sock;

    $bot->del_handler('event tick', 'tick');
    $bot->del_handler('chancmd np', 'rwh_np');
    $bot->del_handler('chancmd listeners', 'rwh_listeners');
}


1;