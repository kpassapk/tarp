package Tarp::PullCSV::book;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    $self->{book} = shift;
    
    return $self;
}

sub heading {
    return "BookID";
}

sub value {
    my $self = shift;
    return $self->{book};
}

1;
