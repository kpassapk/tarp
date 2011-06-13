package Tarp::PullCSV::notes;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub heading { "Notes" }

sub value { "" }

# Shouldn't need to touch below here! #########################################

sub new {
    my $class = shift;
    return bless $class->SUPER::new( @_ ), $class;    
}

1;
