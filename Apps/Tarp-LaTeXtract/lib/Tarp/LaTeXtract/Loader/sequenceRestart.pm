package Tarp::LaTeXtract::Loader::sequenceRestart;

=head1 NAME

Tarp::LaTeXtract::Loader::sequenceRestart - Load C<sequenceRestart> tags

=head1 SYNOPSIS

This module is internal to Tarp::LaTeXtract and is not meant for public
consumption. 

=head1 DESCRIPTION

This module loads a C<sequenceRestart>.

=cut

use base qw/Tarp::LaTeXtract::Loader/;
use strict;

=head2 load

    $ldr->load();

Loads a C<sequenceRestart> tag.

=cut

sub load {
    my $class = shift;
    
    my $es = $class->itemStack();
    my $lev = @$es - 1;
    return $class->_error( "sequenceRestart found at level $lev" )
        unless $lev == -1;
    
#    $class->sequenceChanged( 1 );
    $class->rangeStarted( 0 );
    $class->rangeEnded( 0 );
    
    $class->lastItem( 0 );
    return 1 && $class->SUPER::load();
}

1;