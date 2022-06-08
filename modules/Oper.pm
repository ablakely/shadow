package Oper;

# Oper.pm - IRC Operator Commands
# Written by Aaron Blakely <aaron@ephasic.org>

my $bot = Shadow::Core;
my $help = Shadow::Help;

sub loader {
  if ($bot->isOperMode()) {
    $bot->add_handler('privcmd kill', 'oper_kill');
  } else {
    $bot->log("[Oper] Error: Oper credentials not supplied")
  }

  $help->add_help('kill', 'Oper', '<who> <reason>', 'Uses the IRC Operator KILL command on a user.', 1, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02kill\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "kill is used to force disconnect a user from the IRC network.");
    $bot->say($nick, "\x02SYNTAX\x02: /msg $Shadow::Core::nick kill <who> <reason>");
  });
}

sub oper_kill {
  return if !$bot->isOperMode();

  my ($nick, $host, $text) = @_;
  my ($who, @reason_) = split (/ /, $text);
  my $reason = join(' ', @reason_);

  if (!$reason) { $reason = "KILL commanded by $nick" };

  if ($bot->isbotadmin($nick, $host)) {
    $bot->raw("KILL $who :$reason");
    $bot->log("[Oper] KILL[$who :$reason] command executed by $nick ($host)");
  } else {
    $bot->notice($nick, "Access denied.");
    $bot->log("[Oper] KILL[$who :$reason] command attempt [non bot admin] by $nick ($host)");
  }
}

sub unloader {
  $bot->del_handler('privcmd kill', 'oper_kill');
  $help->del_help('kill', 'Oper');
}

1;
