package Tarp::PullCSV::tec;

use strict;
use base qw/Tarp::PullCSV::Column/;

# TEC: "1" if the line the exercise is on contains an fbox, 0 otherwise

sub heading { "TEC" }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->{_attr}->inherit( 1 );
    
    bless $self, $class;
    return $self;
}

sub value {
    my $self = shift;
    my $listData = shift;
    my ( $exBuffer ) = @{$listData}{ qw/ exBuffer / };
    
    # Does the first line of the exercise buffer contain
    # "fbox"?  If so, return true.  Otherwise, false.
    
    return $exBuffer->[0] =~ /fbox/ ? 1 : 0;
}

1;