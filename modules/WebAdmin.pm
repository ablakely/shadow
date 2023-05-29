package WebAdmin;

use Encode qw(encode);
use lib './modules';
use IO::Socket::INET;
use IO::Select;
use POSIX;
use EJS::Template;
use File::MimeInfo;
use MIME::Base64;
use URL::Encode qw/url_params_mixed/;

use Shadow::Core;
use Shadow::Help;

use Data::Dumper;

my $bot    = Shadow::Core->new();
my $help   = Shadow::Help->new();
my $select = new IO::Select;
our $router;
our $routes;
our %auth;
my $loadedBotStats = 0;

our $sock;
our (%inbuf, %outbuf, %ready, %sockmap);
our $updateLastCheck;
our $updateReady = 0;

my $cfg;
# public interface
sub new {
    return shift();  # return class
}

sub navbar { shift; return $routes->navbar(@_); }
sub add_navbar_link { shift; return $routes->add_navbar_link(@_); }
sub del_navbar_link { shift; return $routes->del_navbar_link(@_); }
sub router { return $router; }
sub routes { return $routes; }
sub checkSession { shift; return $routes->checkSession(@_); }
sub out {
    my ($self, $client, $data) = @_;

    $outbuf{$client} .= $data;
}

sub render {
    my ($self, $template, $args) = @_;
    my $wa = WebAdmin->new();
    my $buf;

    $args->{favicon} = $router->b64img("../favicon.ico");
    
    if (exists($args->{nav_active})) {
        my @tmp = $wa->navbar($args->{nav_active});
        $args->{navbar}  = \@tmp;
    }

    $args->{include} = sub {
        my ($file, $incargs, $filebuf, $buf) = @_;

        # merge args hashes, overwrite with args called using include(file, { args })
        if ($incargs) {
            foreach my $k (keys %{$incargs}) {
                $args->{$k} = $incargs->{$k};
            }
        }

        EJS::Template->process("./modules/WebAdmin/templates/$file", $args, \$buf);

        return $buf;
    };

    EJS::Template->process("./modules/WebAdmin/templates/$template", $args, \$buf);

    return $buf;
}

# private
sub loader {
    $cfg = $Shadow::Core::cfg->{Modules}->{WebAdmin};
    $bot->register("WebAdmin", "v1.0", "Aaron Blakely", "Web Administration Panel and HTTP Server");

    require WebAdmin::Routes;
    require WebAdmin::Router;

    if (!$bot->isloaded("BotStats")) {
        $bot->load_module("BotStats");
        $loadedBotStats = 1;
    }
    
    $router = WebAdmin::Router->new();    
    $routes = WebAdmin::Routes->new($bot, $router);

    my $host = $cfg->{httpd}->{addr} ? $cfg->{httpd}->{addr} : "0.0.0.0";
    my $port = $cfg->{httpd}->{port} ? $cfg->{httpd}->{port} : 8888;

    $sock = IO::Socket::INET->new(
        LocalHost  => $host,
        LocalPort  => $port,
        Proto      => 'tcp',
        Listen     => SOMAXCONN,
        Blocking   => 0,
        Reuse      => 1,
        # Timeout    => .1
    ) or return $bot->err("WebAdmin: Cannot create socket on port $port.");

    $select->add($sock);

    $bot->log("WebAdmin: HTTP Server started on port $port.", "System");

    $routes->initRoutes();

    if ($@) {
        $bot->err($@);
    }

    $bot->add_handler('event tick', 'wa_tick');


    if ($cfg->{sys}->{checkupdate}) {
        checkGitUpdate();
        $bot->add_timeout(43200, "wa_checkupdate");
    }
}

sub checkGitUpdate {
    $bot->log("[WebAdmin - Update Checker] Checking for updates.", "WebAdmin");
    $updateLastCheck = time;

    system "git fetch";

    my $currver = `git rev-parse HEAD`;
    my $newver  = `git rev-parse \@{u}`;

    chomp $currver;
    chomp $newver;

    if ($currver eq $newver) {
        $updateReady = 0;
    } else {
        $updateReady = 1;
    }
}

sub wa_checkupdate {
    checkGitUpdate();

    if ($updateReady) {
        $bot->log("[WebAdmin - Update Checker] Update is available.", "System");
    } else {
        $bot->add_timeout(43200, "wa_checkupdate");
    }
}


sub reloadRoutes {
    delete $INC{'WebAdmin/Routes.pm'};
    require WebAdmin::Routes;

    $routes = WebAdmin::Routes->new($bot, $router);
}

sub setnonblock {
    my ($sock) = @_;
    my ($flags, $set_it);

    # turn off blocking
    if ($^O eq 'MSWin32') {
        $set_it = "1";
        ioctl($sock, 0x80000000 | (4 << 16) | (ord('f') << 8) | 126, $set_it) or return $bot->err("WebAdmin: can't ioctl(): $!");
    } else {
        $flags = fcntl($sock, F_GETFL, 0) or return $bot->err("WebAdmin can't getfl(): $!");
        $flags = fcntl($sock, F_SETFL, $flags | O_NONBLOCK) or return $bot->err("WebAdmin: can't ioctl(): $!");
    }
}

sub closeClient {
    my ($client) = @_;

    delete $inbuf{$client};
    delete $outbuf{$client};
    delete $ready{$client};
    delete $sockmap{$client->peerhost()};

    $select->remove($client);
    close $client;
}

sub wa_tick {
    foreach my $client ($select->can_read(1)) {
        if ($client == $sock) {
            $client = $sock->accept();

            $select->add($client);
            setnonblock($client);
        } else {
            my $count = $client->recv(my $data, POSIX::BUFSIZ, 0);
            unless(defined($count) && length $data) {
                next;
            }
            
            handleHTTPRequest($client, $data);
        }
    }

    foreach my $client ($select->can_write(1)) {
        next unless exists $outbuf{$client};
        
        closeClient($client) if (!$client->peeraddr());

        $outbuf{$client} = encode('UTF-8', $outbuf{$client});
        my $count = $client->send($outbuf{$client}, 0) or return closeClient($client);

        $outbuf{$client} = substr($outbuf{$client}, $count, length($outbuf{$client}));

        if ($count == length $outbuf{$client} || $! == POSIX::EWOULDBLOCK) {

            if (length $outbuf{$client} >= $count) {
                closeClient($client);
            }
        }
        next unless (defined $count);
    }
}

sub flushOut {
    my ($client) = @_;

    print $client $outbuf{$client};
    $outbuf{$client} = '';
}

sub handleHTTPRequest {
    my ($client, $data) = @_;

    my ($headers, @raw) = parseHeaders($client, $data);
    $sockmap{$client->peerhost()} = $client;

    $bot->log("[WebAdmin] Received HTTP request from ".$client->peerhost().": ".$headers->{method}." ".$headers->{url}, "WebAdmin");

    my $tmpstr = join("", @raw);
    chomp $tmpstr;

    if ($headers->{url} =~ /(.*?)\?(.*)/) {
        if (!$tmpstr) {
            $tmpstr = $2;
        }
    }

    my $params = url_params_mixed($tmpstr);

    unless ($router->handle($client, $headers->{method}, $headers->{url}, $params, $headers)) {
        if (-e "./modules/WebAdmin/www".$headers->{url}) {
            my $size = -s "./modules/WebAdmin/www".$headers->{url}; 


            $router->headers($client, { 
                'Content-Type'   => mimetype("./modules/WebAdmin/www".$headers->{url}),
                'Last-Modified'  => strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime((stat "./modules/WebAdmin/www".$headers->{url})[9])),
                'Cache-Control'  => "max-age=604800"
            
            });
            flushOut($client);
            
            print $client "\r\n\r\n";

            open(my $fh, "<:raw", "./modules/WebAdmin/www".$headers->{url}) or $bot->err("[WebAdmin] File error: $!");
            {
                local $/;
                binmode $client, ":raw" or print "binmode failed: $!\n";

                my $data;

                read($fh, $data, $size);
                $outbuf{$client} .= $data;

            }
            close($fh);


        } else {
            $router->headers($client, {'status' => 404 });
            $outbuf{$client} .= "<h2>404 not found!</h2>\r\n";
        }
    }
}

sub parseHeaders {
    my ($client, $data, %headers) = @_;
    my @raw;

    my @tmp = split(/\n/, $data);

    foreach my $line (@tmp) {
        if ($line =~ /(.*?) (.*?) HTTP\/1\.1/) {
            $headers{method} = $1;
            $headers{url} = $2;
        } elsif ($line =~ /(.*?): (.*)/) {
            if ($1 eq "Cookie") {
                my @cookies = split(/; /, $2);
                my %tmp;

                foreach my $c (@cookies) {
                    if ($c =~ /(.*?)=(.*)/) {
                        $tmp{$1} = $2;
                        chomp $tmp{$1};
                        $tmp{$1} =~ s/\r//gs;
                    }
                }

                $headers{cookies} = \%tmp;
            } else {
                $headers{$1} = $2;
            }
        } else {
            push(@raw, $line);
        }
    }

    shift @raw;

    return (\%headers, @raw);
}

sub unloader {
    $bot->unregister("WebAdmin");

    $bot->del_handler('event tick', 'wa_tick');


    delete $INC{'WebAdmin/Router.pm'};
    delete $INC{'WebAdmin/Routes.pm'};

    if ($loadedBotStats) {
        $bot->unload_module("BotStats");
    }

    close $sock;
}

1;
