package Tarp::PullCSV::master;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub heading { "MasterID" }

my $MACROSTART = "TCIMACRO";
my $MACROEND   = "EndExpansion";

# Shouldn't need to touch below here! #########################################

sub new {
    my $class = shift;
    my $csv = shift;
    my $self = bless $class->SUPER::new( $csv,
        'Tarp::Itexam::Attribute::Master' ), $class;
    
    $self->{_attr}->startTag( $MACROSTART );
    $self->{_attr}->endTag( $MACROEND );
    
    return $self;
}

# set the refFormats for Itexam::Attribute::Master
# using the tas entry 'masterRef'
sub preProcess {
    my $self = shift;
    my $args = shift;
    my $xtr = $args->{eXtractor};

    die "Error: 'master' column requires the 'masterRef' .tas entry.\n"
        unless $xtr->style()->exists( "masterRef" );
    
    my @masterRefs = $xtr->style()->interpolate( "masterRef" );
    
    $self->{_attr}->refFormats( \@masterRefs );
}

1;
