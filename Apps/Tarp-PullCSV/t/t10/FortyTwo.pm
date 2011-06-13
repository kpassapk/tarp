package FortyTwo;

# Used in c02.  A column that returns "42"

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new( @_ ), $class;
    return $self;
}

sub heading { "FortyTwo" }

sub value {
    return 42;
}

1;
