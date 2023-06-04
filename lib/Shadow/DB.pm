package Shadow::DB;
# Shadow::DB - JSON database module
#
# This is a centralized impelementation of a JSON based database
# that is provided to make presistant data storage easier for modules.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Aaron Blakely
#

use strict;
use warnings;
use Carp;
use JSON;

sub new {
    my ($class) = @_;

    my $self = {
        filename => "", 
        buf      => {}
    };

    return bless($self, $class);
}

sub read {
    my ($self, $file) = @_;

    $self->{filename} = $file ? "./etc/$file" : "./etc/shadow.db";
    my $tmp;

    if (-e $self->{filename}) { 
        open(my $fh, "<", $self->{filename}) or return 0;
        {
            local $/;
            $tmp = <$fh>;

        }
        close($fh) or return 0;

        $self->{buf} = from_json($tmp, { utf8 => 1 });
        return \$self->{buf};
    } else {
        open(my $fh, ">", $self->{filename}) or return 0;

        print $fh "{}\n";

        close($fh) or return 0;
        return \$self->{buf};
    }

    return 0;
}

sub write {
    my ($self, $free, $pretty) = @_;

    if (!exists($self->{buf})) {
        if (&Shadow::Core::log) {
            Shadow::Core::log(1, "Error: [DB] Write called on freed instance.", "System");
            return 0;
        } else {
            confess("Error: [DB] Write called on freed instance.");
        }
    }

    $pretty = 0 if (scalar(@_) < 3);
    $free   = 1 if (scalar(@_) < 2);

    my $tmp = to_json($self->{buf}, { utf8 => 1, pretty => $pretty });

    open(my $fh, ">", $self->{filename}) or return 0;
    print $fh $tmp."\n";
    close($fh) or return 0;

    return 1;
}

sub free {
    my ($self) = @_;

    delete $self->{buf} if (exists($self->{buf}));
}

1;
