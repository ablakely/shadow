package Shadow::Help;
# Shadow::Help - Shadow Help System
#
# This provides a built in help command that modules may extend
# as well as handle their own subtopics with.
#
# Written by Aaron Blakely <aaron@ephasic.org>

use strict;
use warnings;
use Shadow::Core;

our $bot;
our $module;
our %cmdlist = (
  General => {
    help => {
      cmd       => 'help',
      syntax    => '<topic>',
      shortdesc => 'Displays help information.',
      adminonly => 0,
    },
  },
);


sub new {
  my ($class, $shadow) = @_;
  my $self             = {};
  $bot                 = $shadow;

  if (!$shadow) {
      $bot = Shadow::Core->new();
      return $class;
  }

  $bot->add_handler("privcmd help", 'dohelp');
  return bless($self, $class);
}

# add_help - Adds an item to the /msg bot help command.
# Arguments:
#  cmd      - Command name
#  class    - Section of the help menu the command appears in
#  syntax   - syntax of the command
#  admincmd - 1 for yes, 0 for no designates if the command is admin only
#  subref   - reference to an anonymous sub that prints detailed
#             info about the command.

sub add_help {
  my ($self, $cmd, $class, $syntax, $desc, $admincmd, $subref) = @_;
  $admincmd = 0 if !$admincmd;

  $cmdlist{$class}->{$cmd} = {
    cmd       => $cmd,
    syntax    => $syntax,
    shortdesc => $desc,
    adminonly => $admincmd,
    subref    => $subref
  };
}

sub del_help {
  my ($self, $cmd, $class) = @_;

  delete $cmdlist{$class}{$cmd};
}

sub check_admin_class {
  my ($class) = @_;


  foreach my $k (keys %cmdlist) {
    if ($k eq $class) {
      foreach my $cmd (keys %{$cmdlist{$k}}) {
        if ($cmdlist{$k}->{$cmd}{adminonly}) {
          return 1;
        }
      }
    }
  }

  return 0;
}

# IRC Handlers, these shouldn't be called directly.
sub dohelp {
  my ($nick, $host, $text) = @_;
  my $tab = "    ";
  my @out;

  my $nmax = 0;
  my $smax = 0;

  push(@out, "\x02*** SHADOW HELP ***\x02");

  if ($text) {
    if ($text eq "help" || $text eq "HELP") {
      push(@out, "Help for \x02HELP\x02:");
      push(@out, " ");
      push(@out, "Displays information for commands.");
      push(@out, "\x02SYNTAX\x02: help <command>");

      return;
    } else {
      my @tsplit = split(" ", $text);
      foreach my $c (keys %cmdlist) {
        foreach my $i (keys %{$cmdlist{$c}}) {
          if (lc($i) eq lc($tsplit[0])) {
            return &{$cmdlist{$c}->{$i}{subref}}($nick, $host, $text); 
          }
        }
      }
    }

    return push(@out, "\x02Error\x02: No such help topic: $text");
  }

  my ($ci, $cfmt, $si, $sfmt) = (0, "", 0, "");

  foreach my $c (keys %cmdlist) {
    foreach my $i (keys %{$cmdlist{$c}}) {
      $nmax = length $cmdlist{$c}->{$i}{cmd} if (length $cmdlist{$c}->{$i}{cmd} >= $nmax);
      $smax = length $cmdlist{$c}->{$i}{syntax} if (length $cmdlist{$c}->{$i}{syntax} >= $smax);
    }
  }

  foreach my $c (keys %cmdlist) {
    if (check_admin_class($c)) {
      if ($bot->isbotadmin($nick, $host)) {
        push(@out, " ");
        push(@out, "\x02$c Commands\x02");
      }
    } else {
      push(@out, " ");
      push(@out, "\x02$c Commands\x02");
    }

    foreach my $k (keys %{$cmdlist{$c}}) {
      if ($nmax >= length($cmdlist{$c}->{$k}{cmd})) {
        $ci   = $nmax - length $cmdlist{$c}->{$k}{cmd};
        $cfmt = " " x $ci;
      }
      if ($smax >= length $cmdlist{$c}->{$k}{syntax}) {
        $si   = $smax - length $cmdlist{$c}->{$k}{syntax};
        $sfmt = " " x $si;
      }

      if ($cmdlist{$c}->{$k}{adminonly}) {
        if ($bot->isbotadmin($nick, $host)) {
          push(@out, "$tab\x02".$cmdlist{$c}->{$k}{cmd}."\x02".$cfmt."$tab".
               $cmdlist{$c}->{$k}{syntax}.$sfmt."$tab".$cmdlist{$c}->{$k}{shortdesc});
        } else {
          next;
        }
      } else {
        push(@out, "$tab\x02".$cmdlist{$c}->{$k}{cmd}."\x02".$cfmt."$tab".
              $cmdlist{$c}->{$k}{syntax}.$sfmt."$tab".$cmdlist{$c}->{$k}{shortdesc});
      }
    }
  }

  push(@out, " ");
  push(@out, "[F] means the command may be used in a channel.  Example: ".$Shadow::Core::options{irc}->{cmdprefix}."op user");

  if ($nick =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/gm) {
    push(@out, "Use \x02/help <topic>\x02 for command specific information.");
    foreach my $line (@out) {
      $bot->notice($nick, $line);
    }
  } else {
    push(@out, "Use \x02/msg $Shadow::Core::nick help <topic>\x02 for command specific information.");
    $bot->fastsay($nick, @out);
  }
}

sub cmdprefix {
    my ($self, $nick) = @_;

    return $bot->is_term_user($nick) ? "/" : "/msg $Shadow::Core::nick ";
}

1;
