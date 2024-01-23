package OpenAI;

# OpenAI.pm - OpenAI interface module for Shadow
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyleft 2024 (C) Ephasic Software
#
# installdepends.pl macros:
#$INDEP[OpenAI::API]

use OpenAI::API;
use LWP::Simple;

my $bot = Shadow::Core;
my @conversation = (
    { role => "system", "content" => "You are an IRC bot." }
);

sub loader {
    $bot->add_handler('chancmd ai', 'ai_do');
    #$bot->add_handler('chancmd aipic', 'ai_pic');
}

sub isgd {
    my ($text) = @_;
    my $url = get("https://is.gd/create.php?format=simple&url=$text") or $bot->err("is.gd: $!");

    print "dbug: $url\n";
    return $url;
}

sub fetchAIResponse {
    my ($text, $nick, $chan) = @_;
    my $conf = $Shadow::Core::cfg->{Modules}->{OpenAI};


    my $openai = OpenAI::API->new(
        api_key => "".$conf->{api}->{key},
        timeout => 20
    );

    my $max_tokens  = 0 + $conf->{api}->{maxtokens};
    my $temperature = 0 + $conf->{api}->{temperature};
    my $source = $chan ? "From $nick in $chan:" : "From $nick in PM: ";

    push(@conversation, { role => "user", "content" => $source.$text });

    my $res = $openai->chat(
        messages => \@conversation,
        max_tokens => $max_tokens,
        temperature => $temperature
    );

    push(@conversation, { role => "system", "content" => "$res" });

    return $res;
}

sub ai_pic {
    my ($nick, $host, $chan, $text) = @_;
    my $conf = $Shadow::Core::cfg->{Modules}->{OpenAI};

    my $openai = OpenAI::API->new(
        api_key => "".$conf->{api}->{key}
    );

    my $images = $openai->image_create(
        prompt => $text,
        n => 1
    );

    foreach my $img (@{$images->{data}}) {
        $bot->say($chan, isgd($img->{url}));
    }
}


sub ai_do {
    my ($nick, $host, $chan, $text) = @_;

    my $res = fetchAIResponse($text, $nick, $chan);
    my @responses = split(/\n/, $res);

    $bot->fastsay($chan, @responses);
}

sub unloader {
    $bot->del_handler('chancmd ai', 'ai_do');
    #$bot->del_handler('chancmd aipic', 'ai_pic');
}

1;
