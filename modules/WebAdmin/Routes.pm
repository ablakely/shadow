package WebAdmin::Routes;

use POSIX;

our $bot;
my $newcfg;

my $tdir = "./modules/WebAdmin/templates";

sub new {
    my ($class, $shadow, $router) = @_;

    my $self = {
        router => $router
    };

    $bot = $shadow;

    return bless($self, $class);
}

sub genpw {
    my $maxchars = 20;
    my @letters = (
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
        'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        'W', 'Z', 'Y', 'Z'
    );

    $maxchars = $maxchars / 2;

    my $alias = "";
    my ($x, $y);

    for (my $i = 0; $i < $maxchars; $i++) {
        $x = int(rand($#letters));
        $y = int(rand(9));

        if ($x % 2) {
            $alias .= lc($letters[$x]);
        } else {
            $alias .= $letters[$x];
        }

        $alias .= $y;
    }

    return $alias;
}

sub array_diff(\@\@) {
	my %e = map{ $_ => undef } @{$_[1]};
	return grep( ! exists( $e{$_} ), @{$_[0]} ); 
}

sub checkSession {
    my ($headers) = @_;

    my $nick = $headers->{cookies}->{nick};
    my $auth = $headers->{cookies}->{auth};

    return 0 if ($nick eq "" || $auth eq "");

    if ($WebAdmin::auth{$nick} eq $auth) {
        return 1;
    }

    return 0;
}

sub updateCfg {
    my ($cfg) = @_;

    $bot->log("[WebAdmin] Rehashing configuration.");

    $bot->updatecfg($newcfg);
    $bot->rehash();
}

sub reloadRoutes {
    my $self = shift;

    WebAdmin::Router->reload();
}

sub reloadWebAdmin {
    $bot->unload_module("WebAdmin");
    $bot->load_module("WebAdmin");
}

sub rehashBot {
    $bot->rehash();
}


sub initRoutes {
    my ($self) = @_;

    my $router = $self->{router};
    my $cfg    = $Shadow::Core::cfg->{Modules}->{WebAdmin};
    my $pubURL = $cfg->{httpd}->{publicURL};

    $router->get('/', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            my $mem = BotStats::memusage();
            if ($mem) {
                $mem    = $mem / 1024;
                $mem    = $mem / 1024;
                $mem    = floor($mem);
            } else {
                $mem = "Unsupported.";
            }

            my $uptime = Time::Seconds->new((time() - $^T));
            my %modlist = $bot->module_stats();

            my $c = 0;
            foreach my $mod (keys %modlist) {
                next if ($mod eq "loadedmodcount");

                if ($mod =~ /Shadow\:\:Mods\:\:/) {
                    $c++;
                }
            }

            EJS::Template->process("$tdir/dash.ejs", {
                favicon => $router->b64img("../favicon.ico"),
                botnick   => $Shadow::Core::nick,
                memusage  => $mem,
                uptime    => $uptime->pretty,
                chancount => scalar(keys(%Shadow::Core::sc)),
                servers   => join(", ", keys(%Shadow::Core::server)),
                modcount  => $c
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;
        } else {
            $router->redirect($client, "/login");
        }
    });

    $router->get('/login', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->redirect($client, "/");
        } else {
            $router->headers($client);

            EJS::Template->process("$tdir/login.ejs", {
                favicon => $router->b64img("../favicon.ico")
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;
        }
    });

    $router->post('/login', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->redirect($client, "/");
        } else {
            my $nick = $params->{ircnick};
            
            if ($bot->isbotadmin($nick, "$nick!".$bot->gethost($nick))) {
                $router->headers($client);

                $WebAdmin::auth{$nick} = genpw();
                $bot->say($nick, "WebAdmin login link: ${pubURL}login-code?n=$nick&k=".$WebAdmin::auth{$nick});

                EJS::Template->process("$tdir/login-code.ejs", {
                    favicon => $router->b64img("../favicon.ico"),
                    ircnick => $nick,
                    botnick => $Shadow::Core::nick
                }, \$buf);

                $WebAdmin::outbuf{$client} .= $buf;
            } else {
                $router->redirect($client, "/login?err=invalidNick");
            }

        }
    });

    $router->get('/login-code', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->redirect($client, "/");
        } else {
            my $nick = $params->{n};
            my $code = $params->{k};

            $bot->log("[WebAdmin] Login from $nick [".$client->peerhost()."]\n");

            if ($code eq $WebAdmin::auth{$nick}) {
                my @cookies;

                push(@cookies, $router->cookie('auth', $code));
                push(@cookies, $router->cookie('nick', $nick));

                $router->redirect($client, "/", \@cookies);
            }
        }
    });

    $router->get('/logout', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            my @cookies;

            my $nick = $headers->{cookies}->{nick};

            push(@cookies, $router->cookie('auth', ''));
            push(@cookies, $router->cookie('nick', ''));

            delete $WebAdmin::auth{$nick};

            $router->redirect($client, "/", \@cookies);
        }
    });

    $router->get('/modules', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            my %modlist = $bot->module_stats();

            my @tmp;
            foreach my $mod (keys %modlist) {
                next if ($mod eq "loadedmodcount");

                if ($mod =~ /Shadow\:\:Mods\:\:(.*)/) {
                    push(@tmp, $1);
                }
            }

            my @mods;

            opendir(MODS, "./modules") or die $!;
            while (my $file = readdir(MODS)) {
	            if ($file =~ /\.pm/) {
                    $file =~ s/\.pm//;
                    push(@mods, $file);
                }
            }

            my @diff = array_diff(@mods, @tmp);
            $router->headers($client);

            EJS::Template->process("$tdir/dash-modules.ejs", {
                favicon => $router->b64img("../favicon.ico"),
                mods => \@tmp,
                unloaded => \@diff,
                modreg   => \%Shadow::Core::modreg
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;
        } else {
            $router->redirect($client, "/");
        } 
    });

    $router->get('/modules/unload', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Unloading module ".$params->{mod}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

            $bot->unload_module($params->{mod});
            $router->redirect($client, "/modules");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/modules/reload', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Reloading module ".$params->{mod}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");
            
            $bot->unload_module($params->{mod});
            $bot->load_module($params->{mod});

            $router->redirect($client, "/modules");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->post('/modules/load', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Loading module ".$params->{module}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

            $bot->load_module($params->{module});
            $router->redirect($client, "/modules");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/configuration', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            my $conf;

            open(my $fh, "<", "./etc/shadow.conf") or return $bot->err("[WebAdmin] Cannot read config: $!");
            {
                local $/;
                $conf = <$fh>;
            }
            close($fh);

            EJS::Template->process("$tdir/dash-config.ejs", {
                favicon => $router->b64img("../favicon.ico"),
                conf    => $conf
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->post('/configuration', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $params->{config} =~ s/\r\n/\n/gs unless ($^O =~ /MSWin32/);
            $newcfg = $params->{config};

            $router->redirect($client, "/configuration");

            $bot->add_timeout(10, "updateCfg");

            $bot->log("[WebAdmin] Configuration file updated [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            EJS::Template->process("$tdir/dash-maint.ejs", {
                favicon => $router->b64img("../favicon.ico")
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/rehash', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->add_timeout(10, "rehashBot");

            $bot->log("[WebAdmin] Rehashing configuration file [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/shutdown', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Shutting down... [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

            system "sleep 3 && kill $$";
            close $client
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/restart', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Restarting [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");

            $router->redirect($client, "/");
            system "sleep 5s && $0 && sleep 1 && kill $$";
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/reload-routes', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Reloading WebAdmin::Routes [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");
            $router->redirect($client, "/maintance?msg=reloaded-routes");

            reloadRoutes();
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/reload-webadmin', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->add_timeout(10, "reloadWebAdmin");
            $bot->log("[WebAdmin] Reloading WebAdmin [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]");


            $router->redirect($client, "/maintance?msg=reloaded-webadmin");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/terminal', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            EJS::Template->process("$tdir/dash-term.ejs", {
                favicon => $router->b64img("../favicon.ico")
            }, \$buf);

            $WebAdmin::outbuf{$client} .= $buf;
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->post('/terminal/api', sub {
        my ($client, $params, $headers, $buf) = @_;


        if (checkSession($headers)) {
            $router->headers($client, {
                'Content-Type' => 'text/plain'
            });

            my $cmd = $params->{cmd};
            my $termenv;
            my $host = $client->peerhost();
            
            open(my $fh, "<", "./modules/WebAdmin/termenv.pl") or return $bot->err("[WebAdmin] cannot read termenv.pl: $!");
            {
                while (my $line = <$fh>) {
                    next if ($line =~ /^\#(.*)/);

                    $termenv .= $line;
                }
            }
            close($fh);

            $termenv .= $cmd;

            eval $termenv;
            if ($@) {
                $WebAdmin::outbuf{$client} .= "\nError: $@";
            }
        } else {
            $router->redirect($client, "/");
        }
    });
}

1;