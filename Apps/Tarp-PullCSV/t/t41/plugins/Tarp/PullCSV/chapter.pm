package Tarp::PullCSV::chapter;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub requireArg { 1 }

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    if ( @_ ) {
        $self->{chapter} = shift;
    } else {
        warn "Warning: column requires an argument\n" unless @_;
        $self->{chapter} = '';
    }
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
