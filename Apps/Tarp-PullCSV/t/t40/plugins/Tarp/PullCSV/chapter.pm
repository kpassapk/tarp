package Tarp::PullCSV::chapter;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    $self->{chapter} = shift;
    return $self;
}

sub heading {
    return "Chapter";
}

sub value {
    my $self = shift;
    return $self->{chapter};
}

1;
