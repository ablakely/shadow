package WebAdmin::Routes;

use POSIX;

our $bot;
my $newcfg;
my $web = WebAdmin->new();

my $tdir = "./modules/WebAdmin/templates";

sub new {
    my ($class, $shadow, $router) = @_;

    my $self = {
        router => $router
    };

    push(@{$self->{navbar}}, { link => "/", icon => "home", text => "Dashboard" });
    push(@{$self->{navbar}}, { link => "/terminal", icon => "codesandbox", text => "Terminal" });
    push(@{$self->{navbar}}, { link => "/modules", icon => "package", text => "Modules" });
    push(@{$self->{navbar}}, { link => "/configuration", icon => "file-text", text => "Configuration" });
    push(@{$self->{navbar}}, { link => "/maintance", icon => "tool", text => "Maintance" });

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
    #shift unless (exists($_[0]->{cookies}));
    my ($self, $headers) = @_;

    $headers = $self if (!$headers);

    my $nick = exists($headers->{cookies}->{nick}) ? $headers->{cookies}->{nick} : "";
    my $auth = exists($headers->{cookies}->{auth}) ? $headers->{cookies}->{auth} : "";

    return 0 if ($nick eq "" || $auth eq "" || !exists($WebAdmin::auth{$nick}));

    if ($WebAdmin::auth{$nick} eq $auth) {
        return 1;
    }

    return 0;
}

sub updateCfg {
    my ($cfg) = @_;

    $bot->log("[WebAdmin] Rehashing configuration.", "WebAdmin");

    $bot->updatecfg($newcfg);
    $bot->rehash();
}

sub updateCfgRestart {
    my ($cfg) = @_;

    $bot->log("[WebAdmin] Updated configuration and restarting.", "WebAdmin");
    $bot->updatecfg($newcfg);

    exit;
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

sub installUpdates {
    $bot->log("[WebAdmin] Installing updates, the bot will restart.");

    system "git pull";
    system "./installdepends.pl";
    exit;
}

# --- public ---
sub navbar {
    my ($self, $active) = @_;
    my @copy = @{$self->{navbar}};
    my @tmp;
    my @ret;

    for (my $i = 0; $i < scalar(@copy); $i++) {
        $copy[$i]->{active} = $copy[$i]->{text} eq $active ? 1 : 0;
        push(@tmp, $copy[$i]->{text});
    }

    @tmp  = sort(@tmp);
    my $i = 0;

    while ($i < scalar(@tmp)) {
        for (my $x = 0; $x < scalar(@copy); $x++) {
            if (exists($copy[$x]->{text}) && exists($tmp[$i])) {
                if ($copy[$x]->{text} eq $tmp[$i]) {
                    push(@ret, $copy[$x]);
                    $i++;
                }
            }
        }
    }

    return @ret;
}
# { link => "", icon => "", text => "" },

sub add_navbar_link {
    my ($self, $link, $icon, $text)  = @_;

    for (my $i = 0; $i < scalar(@{$self->{navbar}}); $i++) {
        return 0 if ($self->{navbar}[$i]->{text} eq $text ||
                     $self->{navbar}[$i]->{link} eq $link);
    }

    push(@{$self->{navbar}}, {
        link => $link,
        icon => $icon,
        text => $text
    });

    return 1;
}

sub del_navbar_link {
    my ($self, $text) = @_;

    for (my $i = 0; $i < scalar(@{$self->{navbar}}); $i++) {
        if ($self->{navbar}[$i]->{text} eq $text) {
            splice(@{$self->{navbar}}, $i, 1);
            return 1;
        }
    }

    return 0;
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

            my @nav = $self->navbar("Dashboard");

            $web->out($client, $web->render("dash.ejs", {
                navbar    => \@nav,
                favicon   => $router->b64img("../favicon.ico"),
                botnick   => $Shadow::Core::nick,
                memusage  => $mem,
                uptime    => $uptime->pretty,
                chancount => scalar(keys(%Shadow::Core::sc)),
                servers   => join(", ", keys(%Shadow::Core::server)),
                modcount  => $c
            }));

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

            $web->out($client, $web->render("login.ejs", {
                favicon => $router->b64img("../favicon.ico"),
                msg => exists($params->{msg}) ? $params->{msg} : undef
            }));

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

                $web->out($client, $web->render("login-code.ejs", {
                    favicon => $router->b64img("../favicon.ico"),
                    ircnick => $nick,
                    botnick => $Shadow::Core::nick
                }));

            } else {
                $router->redirect($client, "/login?msg=invalidnick");
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

            $bot->log("[WebAdmin] Login from $nick [".$client->peerhost()."]", "WebAdmin");

            if ($code eq $WebAdmin::auth{$nick}) {
                my @cookies;

                push(@cookies, $router->cookie('auth', $code));
                push(@cookies, $router->cookie('nick', $nick));

                $router->redirect($client, "/", $headers, \@cookies);
            }
        }

        $router->redirect($client, "/");
    });

    $router->get('/logout', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            my @cookies;

            my $nick = $headers->{cookies}->{nick};

            push(@cookies, $router->cookie('auth', ''));
            push(@cookies, $router->cookie('nick', ''));

            delete $WebAdmin::auth{$nick};

            $router->redirect($client, "/", $headers, \@cookies);
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

            my @nav = $self->navbar("Modules");

            $web->out($client, $web->render("dash-modules.ejs", {
                navbar => \@nav,
                favicon => $router->b64img("../favicon.ico"),
                mods => \@tmp,
                unloaded => \@diff,
                modreg   => \%Shadow::Core::modreg,
                msg      => exists($params->{msg}) ? $params->{msg} : undef
            }));

        } else {
            $router->redirect($client, "/");
        } 
    });

    $router->get('/modules/unload', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Unloading module ".$params->{mod}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            $bot->unload_module($params->{mod});
            $router->redirect($client, "/modules");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/modules/reload', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Reloading module ".$params->{mod}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]"), "WebAdmin";
            
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
            $bot->log("[WebAdmin] Loading module ".$params->{module}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            $bot->load_module($params->{module});
            $router->redirect($client, "/modules");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->post('/modules/download', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Downloading module from ".$params->{url}." [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            system "wget -O ./modules/".$params->{filename}." ".$params->{url};

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

            my @nav = $self->navbar("Configuration");

            $web->out($client, $web->render("dash-config.ejs", {
                navbar  => \@nav,
                favicon => $router->b64img("../favicon.ico"),
                conf    => $conf
            }));

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


            if ($params->{restart} eq "true") {
                $bot->add_timeout(10, "updateCfgRestart");
            } else {
                $bot->add_timeout(10, "updateCfg");
            }

            $bot->log("[WebAdmin] Configuration file updated [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            my $checkTime = $WebAdmin::updateLastCheck ? localtime($WebAdmin::updateLastCheck) : "N/A";

            my @nav = $self->navbar("Maintance");
            $web->out($client, $web->render("dash-maint.ejs", {
                navbar  => \@nav,
                favicon => $router->b64img("../favicon.ico"),
                updateReady => $WebAdmin::updateReady,
                updateLastCheck => $checkTime,
                msg => $params->{msg} ne "" ? $params->{msg} : undef
            }));

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/rehash', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->add_timeout(10, "rehashBot");

            $bot->log("[WebAdmin] Rehashing configuration file [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");
            $router->redirect($client, "/maintance?msg=rehashing");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/shutdown', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Shutting down... [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            my $cmd = "sleep 3 && kill -9 ";
            $cmd .= exists($ENV{STARTER_PID}) ? $ENV{STARTER_PID} : $$;

            close $client;
            system $cmd;
            exit;
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/restart', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->log("[WebAdmin] Restarting [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            $router->redirect($client, "/");
           
            if (exists($ENV{STARTER_PID})) {
                exit;
            } else {
                system "sleep 5s && $0 && sleep 1 && kill $$";
            }
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/reload-webadmin', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $router->redirect($client, "/maintance?msg=reloading-webadmin");
            
            $bot->add_timeout(10, "reloadWebAdmin");
            $bot->log("[WebAdmin] Reloading WebAdmin [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/check-update', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            &WebAdmin::checkGitUpdate();
            $bot->log("[WebAdmin] Checking for updates [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");
            
            $router->redirect($client, "/maintance");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/maintance/install-update', sub {
        my ($client, $params, $headers) = @_;

        if (checkSession($headers)) {
            $bot->add_timeout(60, "installUpdates");
            $bot->log("[WebAdmin] Installing updates in 1 minute [Issued by ".$headers->{cookies}->{nick}.":".$client->peerhost()."]", "WebAdmin");

            $router->redirect($client, "/maintance?msg=installing-updates");
        } else {
            $router->redirect($client, "/");
        }
    });

    $router->get('/terminal', sub {
        my ($client, $params, $headers, $buf) = @_;

        if (checkSession($headers)) {
            $router->headers($client);

            my @nav = $self->navbar("Terminal");

            $web->out($client, $web->render("dash-term.ejs", {
                navbar  => \@nav,
                favicon => $router->b64img("../favicon.ico")
            }));

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
