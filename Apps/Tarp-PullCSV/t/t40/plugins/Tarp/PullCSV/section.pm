package Tarp::PullCSV::section;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub new {
    my $class = shift;
    my $csv = shift;
    my $sections = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    $self->{sections} = defined $sections ? [ split /,/, $sections ] : [];
    return $self;
}

sub heading {
    return "Section";
}
sub value {
    my $self = shift;
    my $args = shift;
    
    return $self->{sections}->[ $args->{exSeq} ];
}

1;
