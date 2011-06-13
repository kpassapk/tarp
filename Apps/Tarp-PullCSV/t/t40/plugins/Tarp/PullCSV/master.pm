package Tarp::PullCSV::master;

use strict;
use base qw/Tarp::PullCSV::Column/;

my $MACROSTART = "TCIMACRO";
my $MACROEND   = "EndExpansion";

sub new {
    my $class = shift;
    my $csv = shift;
    my $self = bless $class->SUPER::new( $csv,
        'Tarp::Itexam::Attribute::Master' ), $class;
    
    $self->{_attr}->startTag( $MACROSTART );
    $self->{_attr}->endTag( $MACROEND );
    
    return $self;
}

sub heading {
    return "MasterID";
}

sub preProcess {
    my $self = shift;
    my $args = shift;
    my $xtr = $args->{eXtractor};
    
    my @masterRefs = $xtr->style()->interpolate( "masterRef", Tarp::Style->NCBUFS () );
    
    $self->{_attr}->refFormats( \@masterRefs );
}

1;
