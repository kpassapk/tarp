package Tarp::LaTeXtract::Loader::List;
use strict;
use base qw/Tarp::LaTeXtract::Loader/;

=head1 NAME

Tarp::LaTeXtract::Loader::List - Load enumerated list tags

This class does not have a load() method, it just provides the following flag
to its subclasses (accessible as a class method)

=over

=item awaitingItem

=back

=cut

my $awaitingItem = 0;

sub awaitingItem {
    shift;
    if ( @_ ) {
        return $awaitingItem = shift;
    } else {
        return $awaitingItem;
    }
}

1;
