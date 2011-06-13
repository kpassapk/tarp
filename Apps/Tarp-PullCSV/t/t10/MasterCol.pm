package MasterCol;

my $MACROSTART = "TCIMACRO";
my $MACROEND   = "EndExpansion";

# Used in c03: A column that returns a MasterID using the
# Itexam::Attribute::Master class.

use strict;
use base qw/Tarp::PullCSV::Column/;

sub heading { "Master" }

sub new {
    my $class = shift;
    my $csv = shift;
    my $self = bless $class->SUPER::new( $csv,
        'Tarp::Itexam::Attribute::Master' ), $class;
    
    $self->{_attr}->startTag( "TCIMACRO" );
    $self->{_attr}->endTag( "EndExpansion" );
    
    return $self;
}

sub preProcess {
    my $self = shift;
    my $args = shift;
    my $xtr = $args->{eXtractor};

    my @masterRefs = $xtr->style()->interpolate( "masterRef", Tarp::Style->NCBUFS () );
    
    $self->{_attr}->refFormats( \@masterRefs );
}

1;
