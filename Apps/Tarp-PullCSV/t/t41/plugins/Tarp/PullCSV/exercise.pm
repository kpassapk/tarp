package Tarp::PullCSV::exercise;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new( shift ), $class;        
    return $self;
}

sub heading {
    return "Problem";
}

sub value {
    my $self = shift;
    my $args = shift;
    return $args->{itemString};
}

1;
