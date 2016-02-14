package Shadow::Help;

use strict;
use warnings;

our $bot;
our $module;
our %cmdlist = (
  help => {
    cmd       => 'help',
    syntax    => '<topic>',
    shortdesc => 'Displays help information.',
    adminonly => 0},
);


sub new {
  my ($class, $shadow) = @_;
  my $self             = {};
  $bot                 = $shadow;

  $bot->add_handler("privcmd help", 'dohelp');
  return bless($self, $class);
}

sub add_help {
  my ($self, $cmd, $syntax, $desc, $admincmd) = @_;
  $admincmd = 0 if !$admincmd;

  $cmdlist{$cmd} = {
    cmd       => $cmd,
    syntax    => $syntax,
    shortdesc => $desc,
    adminonly => $admincmd
  };
}

# IRC Handlers, these shouldn't be called directly.
sub dohelp {
  my ($nick, $host, $text) = @_;
  my $tab = "    ";

  my $nmax = 0;
  my $smax = 0;

  my ($ci, $cfmt, $si, $sfmt) = (0, "", 0, "");

  foreach my $i (keys %cmdlist) {
    $nmax = length $cmdlist{$i}{cmd} if (length $cmdlist{$i}{cmd} >= $nmax);
    $smax = length $cmdlist{$i}{syntax} if (length $cmdlist{$i}{syntax} >= $smax);
  }

  $bot->notice($nick, "\x02*** SHADOW HELP ***\x02");

  foreach my $k (keys %cmdlist) {
    if ($nmax >= length($cmdlist{$k}{cmd})) {
      $ci   = $nmax - length $cmdlist{$k}{cmd};
      $cfmt = " " x $ci;
    }
    if ($smax >= length $cmdlist{$k}{syntax}) {
      $si   = $smax - length $cmdlist{$k}{syntax};
      $sfmt = " " x $si;
    }

    if ($cmdlist{$k}{adminonly}) {
      if ($bot->isbotadmin($nick, $host)) {
        $bot->notice($nick, "$tab\x02".$cmdlist{$k}{cmd}."\x02".$cfmt."$tab".$cmdlist{$k}{syntax}.$sfmt."$tab".$cmdlist{$k}{shortdesc});
      } else {
        next;
      }
    } else {
      $bot->notice($nick, "$tab\x02".$cmdlist{$k}{cmd}."\x02".$cfmt."$tab".$cmdlist{$k}{syntax}.$sfmt."$tab".$cmdlist{$k}{shortdesc});
    }
  }

  $bot->notice($nick, " ");
  $bot->notice($nick, "[F] means the command can also be executed in a channel.  Example: .op user");
  $bot->notice($nick, "Use \x02/msg $Shadow::Core::nick help <topic>\x02 for command specific information.");
}


1;
