package Weather;

use POSIX;
use JSON;
use LWP::UserAgent;
use open qw(:std :utf8);

my $bot = Shadow::Core;
my $help = Shadow::Help;

my $API_KEY = "3871e6ee92a6ffee1850e3e8175c107d";

my @usStates = ( 'AL', 'AK', 'AS', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FM', 'FL', 'GA', 'GU', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MH', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'MP', 'OH', 'OK', 'OR', 'PW', 'PA', 'PR', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VI', 'VA', 'WA', 'WV', 'WI', 'WY' );
my @caProvidences = ( 'AB', 'BC', 'MB', 'NB', 'NL', 'NT', 'NS', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');

my %usp = map { $_ => 1 } @usStates;
my %cap = map { $_ => 1 } @caProvidences;

sub loader {
    $bot->register("Weather", "v0.5", "Aaron Blakely");

    $bot->add_handler('chancmd weather', 'doWeather');
    $bot->add_handler('chancmd w', 'doWeather');
}

sub fetchWeatherJSON {
    my ($loc) = @_;

    my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0} );

    if ($loc =~ /^-?(0|([1-9][0-9]*))(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) {
        my $res = $ua->get("http://api.openweathermap.org/data/2.5/weather?zip=$loc&units=imperial&appid=$API_KEY");

        if ($res->is_success) {
            print $res->decoded_content;

            return from_json($res->decoded_content, { utf8 => 1 });
        }
    } else {
        my $res = $ua->get("http://api.openweathermap.org/data/2.5/weather?q=$loc&units=metric&appid=$API_KEY");

        if ($res->is_success) {
            print $res->decoded_content;
            return from_json($res->decoded_content, { utf8 => 1 });
        }
    }


}

sub doWeather {
    my ($nick, $host, $chan, $text) = @_;
    
    my $WOUT;
    my $useF = 0;

    if (!$text) {
        return $bot->notice($nick, "Command usage: weather <city | postal code> (example: .w Memphis, TN)");
    }

    my @inputSplit = split(/\, /, $text);
    my $len = @inputSplit;

    if ($len == 2) {
        if (exists($usp{$inputSplit[1]})) {
            $text .= ", US";
            $useF = 1;
        } elsif (exists($cap{$inputSplit[1]})) {
            $text .= ", CA";
        }
    }

    my $weather = fetchWeatherJSON($text);
    chomp $weather->{sys}->{country};

    if ("$weather->{sys}->{country}" eq "US") {

        if ($useF == 1 && (($weather->{main}->{temp} * 9/5) + 32) < 120) {
            $weather->{main}->{temp} = ($weather->{main}->{temp} * 9/5) + 32;
            $weather->{main}->{feels_like} = ($weather->{main}->{feels_like} * 9/5) + 32;
        }

        if ($inputSplit[1] ne "") {
            $weather->{name} .= ", $inputSplit[1]";
        }

$WOUT = <<EOF;
\002Name:\002 $weather->{name} \002Temp:\002 $weather->{main}->{temp}\N{U+00B0}F (Feels Like: $weather->{main}->{feels_like}\N{U+00B0}F) \002Conditions:\002 $weather->{weather}->[0]->{main} ($weather->{weather}->[0]->{description}) \002Wind Speed:\002 $weather->{wind}->{speed} MPH \002Humidity:\002 $weather->{main}->{humidity}%
EOF
    } else {
$WOUT = <<EOFC;
\002Name:\002 $weather->{name} \002Temp:\002 $weather->{main}->{temp}\N{U+00B0}C (Feels Like: $weather->{main}->{feels_like}\N{U+00B0}C) \002Conditions:\002 $weather->{weather}->[0]->{main} ($weather->{weather}->[0]->{description}) \002Wind Speed:\002 $weather->{wind}->{speed} KMH \002Humidity:\002 $weather->{main}->{humidity}%
EOFC
    }


    chomp $WOUT;
    $bot->say($chan, $WOUT);
}

sub unloader {
    $bot->unregister("Weather");

    $bot->del_handler('chancmd weather', 'doWeather');
    $bot->del_handler('chancmd w', 'doWeather');
}

1;
