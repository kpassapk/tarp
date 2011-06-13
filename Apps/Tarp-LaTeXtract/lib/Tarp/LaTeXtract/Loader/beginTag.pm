package Tarp::LaTeXtract::Loader::beginTag;

=head1 NAME

Tarp::LaTeXtract::Loader::beginTag - Load C<beginTags>

=head1 SYNOPSIS

This module is internal to Tarp::LaTeXtract and is not meant for public
consumption. 

=cut

use strict;
use base qw/Tarp::LaTeXtract::Loader::List/;

=head2 load

    Tarp::LaTeXtract::Loader::beginTag->load();

Loads a C<beginTag>.

=cut

sub load {
    my $class = shift;
    
    my $es = $class->itemStack();
    
    return $class->_error( "beginTag at maximum level (2)" )
        if @$es == 3;

    return $class->_error( "Two consecutive beginTags" )
        if $class->_lastLoader() &&
           $class->_lastLoader()->isa( "Tarp::LaTeXtract::Loader::beginTag" );
    
    push @$es, $class->lastItem(); # Increment stack level with saved value
    
    $class->awaitingItem( 1 );
    $class->itemStack( $es );
    
    $class->rangeStarted( 0 );
    $class->rangeEnded( 0 );
    
    return 1 && $class->SUPER::load(); 
}

1;