package WebAdmin::Router;
use strict;
use warnings;
use POSIX;
use MIME::Base64;
use File::MimeInfo;

my $bot = Shadow::Core->new();

sub new {
    my $class = shift;
    my $self  = (
        'GET_MAP'  => {},
        'POST_MAP' => {}
    );

    return bless($self, $class);
}

sub get {
    my ($self, $path, $subref) = @_;

    if (!exists($self->{GET_MAP}{$path})) {
        $bot->log("[WebAdmin::Router] Adding GET route: $path", "WebAdmin");
        $self->{GET_MAP}{$path} = $subref;
    } else {
        $bot->err("[WebAdmin::Router] Path already exists: $path", 0, "WebAdmin");
    }
}

sub post {
    my ($self, $path, $subref) = @_;

    if (!exists($self->{POST_MAP}{$path})) {
        $bot->log("[WebAdmin::Router] Adding POST route: $path", "WebAdmin");
        $self->{POST_MAP}{$path} = $subref;
    } else {
        $bot->err("[WebAdmin::Router] Path already exists: $path", 0, "WebAdmin");
    }
}

sub del {
    my ($self, $type, $path) = @_;

    if ($type =~ /post/i) {
        if (exists($self->{POST_MAP}{$path})) {
            $bot->log("[WebAdmin::Router] Removing POST route path: $path", "WebAdmin");
            delete $self->{POST_MAP}{$path};

            return 1;
        }
    } elsif ($type =~ /get/i) {
        if (exists($self->{GET_MAP}{$path})) {
            $bot->log("[WebAdmin::Router] Removing GET route path: $path", "WebAdmin");
            delete $self->{GET_MAP}{$path};

            return 1;
        }
    }

    return 0;
}

sub handle {
    my ($self, $client, $method, $url, $params, $headers) = @_;

    my @tmp = split(/\?/, $url);
    $url = $tmp[0];

    if ($method eq "GET") {
        if (exists($self->{GET_MAP}{$url})) {
            &{$self->{GET_MAP}{$url}}($client, $params, $headers);

            return 1;
        
        }
    } elsif ($method eq "POST") {
        if (exists($self->{POST_MAP}{$url})) {
            &{$self->{POST_MAP}{$url}}($client, $params, $headers);

            return 1;
        }
    }

    return 0;
}

sub headers {
    my ($self, $client, $args) = @_;
    
    $args->{'status'}         = exists($args->{'status'}) ? $args->{'status'} : 200;
    $args->{'status_txt'}     = exists($args->{'status_txt'}) ? $args->{'status_txt'} : "OK";
    $args->{'Date'}           = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time));
    $args->{'Server'}         = "Shadow Web Admin HTTP Server";
    $args->{'Connection'}     = "close";
    $args->{'Content-Type'}   = exists($args->{'Content-Type'}) ? $args->{'Content-Type'} : "text/html";
    #$args{'Content-Length'} = exists($args{'Content-Length'}) ? $args{'Content-Length'} : undef;

    $WebAdmin::outbuf{$client} .= "HTTP/1.1 ".$args->{'status'}." ".$args->{'status_txt'}."\r\n";
    foreach my $key (keys %{$args}) {
        next if ($key eq "status" || $key eq "cookies" || $key eq "status_txt");
        next if ("$key" =~ /HASH\((.*?)\)/);
        next if ($key eq "cookies");

        $WebAdmin::outbuf{$client} .= "$key: ".$args->{$key}."\r\n";
    }

    if (exists($args->{'cookies'}) && $args->{'cookies'}) {
        my @cookies = @{$args->{'cookies'}};

        foreach my $cookie (@cookies) {
            $WebAdmin::outbuf{$client} .= "Set-Cookie: $cookie\r\n";
        }
    }

    $WebAdmin::outbuf{$client} .= "\r\n";
}

sub cookie {
    my ($self, $key, $val, %attribs) = @_;

    $attribs{'httpOnly'} = exists($attribs{'httpOnly'}) ? $attribs{'httpOnly'} : 1;
    $attribs{'maxAge'}   = exists($attribs{'maxAge'}) ? $attribs{'maxAge'} : 60*60*24*7;

    my $cstr = "$key=$val; ";
    foreach my $a (keys %attribs) {
        if ($attribs{$a} == 1) {
            $cstr .= "$a; ";
        } else {
            $cstr .= "$a=".$attribs{$a}."; ";
        }
    }

    return $cstr;
}

sub redirect {
    my ($self, $client, $url, @cookies) = @_;

    return headers($self, $client, {
        status => 302,
        status_txt => "Temporary Redirect",
        Location => $url,
        cookies  => scalar(@cookies) > 0 ? @cookies : undef
    });
}

sub b64img {
    my ($self, $img) = @_;
    my $ret = "data:".mimetype("./modules/WebAdmin/www/$img").";base64,";

    open(my $fh, "<:raw", "./modules/WebAdmin/www/img/$img") or return;
    #{
        my $buf;

        while (read($fh, $buf, 60*57)) {
            $ret .= encode_base64($buf);
        }
    #}

    close($fh);

    return $ret;
}

sub reload {
    my ($self) = @_;

    $self->{GET_MAP} = {};
    $self->{POST_MAP} = {};

    &WebAdmin::reloadRoutes();
}

sub reset {
    my $self = shift;

    $self->{GET_MAP} = {};
    $self->{POST_MAP} = {};
}

1;
