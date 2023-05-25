package MacSysinfo;

# Shadow Module: MacSysinfo
# This provides the .sysinfo brag script for OS X
#
# Written by Aaron Blakely <aaron@ephasic.org>

use Shadow::Core;
use Shadow::Help;

my $bot = Shadow::Core->new();
my $help = Shadow::Help->new();

sub loader {
  if ($^O !~ /darwin/) {
    $bot->err("Error: This module is intended to run on macOS!  Refusing to load.", 0, "Modules");
    return;
  }

  $bot->register("MacSysinfo", "v0.5", "Aaron Blakely", "System information using macOS System Profiler");
  $bot->add_handler('chancmd sysinfo', 'sysinfo_cmd');
  $help->add_help('sysinfo', 'Channel', '', 'System Specifications brag script. [F]', 0, sub {
    my ($nick, $host, $text) = @_;

    $bot->say($nick, "Help for \x02SYSINFO\x02:");
    $bot->say($nick, " ");
    $bot->say($nick, "Prints system information into the channel.");
    $bot->say($nick, "\x02SYNTAX\x02: .sysinfo");
  });
}


sub getMacInfo {
  my @hardinfo = `system_profiler SPHardwareDataType SPSoftwareDataType`;

  my %ret;

  foreach my $line (@hardinfo) {
    chomp $line;

    if ($line =~ /^\s+(Machine|Model) Name\: (.*)$/) {
      $ret{machineName} = $2;
    }
    elsif ($line =~ /^\s+(Machine Model|Model Identifier)\: (.*)$/) {
      $ret{machineModel} = $2;
    }
    elsif ($line =~ /^\s+(CPU|Processor) Speed\: (.*)$/) {
      $ret{cpuSpeed} = $2;
    }
    elsif ($line =~ /^\s+Total Number of Cores\: (.*)$/) {
      $ret{numOfCores} = $1;
    }
    elsif ($line =~ /^\s+(CPU Type|Processor Name)\: (.*)$/) {
      $ret{cpuType} = $2;
    }
    elsif ($line =~ /^\s+(Number Of CPUs|Number of Processors)\: (.*)$/) {
      $ret{numOfCPUs} = $2;
    }
    elsif ($line =~ /^\s+Memory\: (.*)$/) {
      $ret{memory} = $1;
    }
    elsif ($line =~ /^\s+System Version\: (.*)$/) {
      $ret{osVersion} = $1;
    }
    elsif ($line =~ /^\s+Kernel Version\: (.*)$/) {
       $ret{kernelVersion} = $1;
    }
    elsif ($line =~ /^\s+Computer Name\: (.*)$/) {
       $ret{computerName} = $1;
    }
  }

  $ret{software}  = $ret{osVersion}." (Kernel: ".$ret{kernelVersion}.")";

  $ret{hardware}  = $ret{machineName}." (".$ret{machineModel}.")";
  $ret{hardware} .= " CPU (".$ret{numOfCPUs}." installed";
  if ($ret{numOfCores}) {
    $ret{hardware} .= ", ".$ret{numOfCores}." cores";
  }
  $ret{hardware} .= "): ".$ret{cpuType}." @ ".$ret{cpuSpeed};
  $ret{hardware} .= " RAM: ".$ret{memory};

  return \%ret;
}

sub sysinfo_cmd {
  my ($nick, $host, $chan, $text) = @_;

  my $sysinfo = getMacInfo();
  $bot->say($chan, "\x02".$sysinfo->{computerName}."\x02: \x02OS\x02: ".$sysinfo->{osVersion}." \x02Hardware\x02: ".$sysinfo->{hardware});
}

sub unloader {
  $bot->unregister("MacSysinfo");
  $bot->del_handler('chancmd sysinfo', 'sysinfo_cmd');
  $help->del_help('sysinfo', 'Channel');
}

1;
