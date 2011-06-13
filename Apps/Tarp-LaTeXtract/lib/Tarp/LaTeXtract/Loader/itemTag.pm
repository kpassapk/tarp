package Tarp::LaTeXtract::Loader::itemTag;

=head1 NAME

Tarp::LaTeXtract::ItemTagLoader - Load C<itemTag>s

=head1 SYNOPSIS

This module loads a C<itemTag>.

=cut

use strict;
use base qw/Tarp::LaTeXtract::Loader::List/;

=head2 load

    Tarp::LaTeXtract::Loader::itemTag->load();

Loads a C<itemTag_0_>, C<itemTag_1_>, or C<itemTag_2_>

=cut

sub load {
    my $class = shift;
    
    my $es = $class->itemStack();
    return $class->_error( "Item tag at level -1" ) unless @$es;
    
    if ( $class->awaitingItem() ) {
        $class->rangeStarted( 1 );
        $class->rangeEnded  ( 0 );
        $class->awaitingItem( 0 );
    } else {
        $class->rangeStarted( 1 );
        $class->rangeEnded  ( 1 );
    }

    ++($es->[-1]);             # Increment top stack level
    $class->itemStack( $es );
    
    # Set these internal
    $class->lastItem( 0 );

    return 1 && $class->SUPER::load();
}


1;