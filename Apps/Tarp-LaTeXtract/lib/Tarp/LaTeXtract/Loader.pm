package Tarp::LaTeXtract::Loader;

=head1 SYNOPSIS

This module is internal to Tarp::LaTeXtract and is not meant for public
consumption. 

=head1 NAME

Tarp::LaTeXtract::Loader - load item list

=head1 SYNOPSIS

The job of the load() method is to examine and if necessary modify the state()
and additionally set the following notification flags:

=over

=item rangeStarted

True if this tag has started an item line range, false otherwise.

=item rangeEnded

True if this tag has ended an item line range, false otherwise.

=back

=cut

use strict;

my $itemStack = [];
my $rangeStarted    = '';
my $rangeEnded      = '';


my $_lastItem = 0;
my $_lastLoader = undef;

my $_errStr = '';

=head2 begin

    Tarp::LaTeXtract::Loader->begin();

Signals begin of a load event.

=cut

sub begin {
    $itemStack = [];
    $_lastLoader = undef;
    $_lastItem = 0;
}

=head2 end

    Tarp::LaTeXtract::Loader->end();

Signals the end of a load event.

=cut

sub end {}

sub _lastLoader {
    shift;
    if ( @_ ) {
        return $_lastLoader = shift;
    } else {
        return $_lastLoader;
    }
}

=head2 itemStack

    $es = Tarp::LaTeXtract::Loader->itemStack();

Returns an arrayref containing the current item stack

=cut

sub itemStack {
    shift;
    if ( @_ ) {
        return $itemStack = shift;
    } else {
        return $itemStack;
    }
}

=head2 lastItem

    $es = Tarp::LaTeXtract::Loader->lastItem();

=cut

sub lastItem {
    shift;
    if ( @_ ) {
        return $_lastItem = shift;
    } else {
        return $_lastItem;
    }
}

=head2 load

    Tarp::LaTeXtract::Loader->load();

=cut

sub load {
    my $class = shift;
    $class->_lastLoader( $class );
    1;
}

sub _error {
    $_errStr = $_[1];
    '';
}

=head2 errStr

    Tarp::LaTeXtract::Loader->errStr();

Retrieves the error string

=cut

sub errStr { $_errStr }

sub rangeStarted {
    shift;
    if ( @_ ) {
        return $rangeStarted = shift;
    } else {
        return $rangeStarted;
    }
}

sub rangeEnded {
    shift;
    if ( @_ ) {
        return $rangeEnded = shift;
    } else {
        return $rangeEnded;
    }
}

=pod

sub sequenceChanged {
    shift;
    if ( @_ ) {
        return $sequenceChanged = shift;
    } else {
        return $sequenceChanged;
    }
}

=cut

1;