package Tarp::PullCSV::example;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new( shift ), $class;        
    return $self;
}

sub heading { "Example" }

sub value {
    my $args = $_[1];
    return $args->{itemString};
}

1;
