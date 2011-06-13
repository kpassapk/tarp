package Tarp::LaTeXtract::Loader::endTag;

=head1 NAME

Tarp::LaTeXtract::Loader::endTag - Load C<endTag>

=head1 SYNOPSIS

This module is internal to Tarp::LaTeXtract and is not meant for public
consumption. 

=cut

use strict;
use warnings;

use base qw/Tarp::LaTeXtract::Loader::List/;


=head2 load

    Tarp::LaTeXtract::Loader::endTag->load();

Loads an C<endTag>.

=cut

sub load {
    my $class = shift;
    my $tag   = shift;
    my $opts  = shift;
    
    my $es = $class->itemStack();
    
    return $class->_error( "endTag at file level" )
        unless @$es;

    $class->rangeStarted   ( 0 );
    
    if ( $class->awaitingItem()  ) {
        if ( $opts->{relax} ) {
            $class->rangeEnded( 0 );
        } else {
            return $class->_error( "endTag after beginTag with no item tags in between" );
        }
    } else {
        $class->rangeEnded     ( 1 );
    }
    
    $class->lastItem( $es->[-1] );

    pop @$es;                       # Decrement stack level
    $class->itemStack( $es );

    return 1 && $class->SUPER::load();
}

1;