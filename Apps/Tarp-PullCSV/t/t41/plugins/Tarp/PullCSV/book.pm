package Tarp::PullCSV::book;

use strict;
use base qw/Tarp::PullCSV::Column/;
use Carp qw/cluck/;

sub requireArg { 1 }

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    
    if ( @_ ) {
        $self->{book} = shift;
    } else {
        warn "Warning: 'book' column requires an argument\n" unless @_;
        $self->{book} = '';
    }
    
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
