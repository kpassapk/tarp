package Tarp::LaTeXcombine::Pickup;

=head1 NAME

Tarp::LaTeXcombine::Pickup - Base class for pickup types

=cut

use Carp;
use strict;

our $AUTOLOAD;

my %fields = (
    style => undef,
);

=head1 METHODS

=head2 new

    $p = Tarp::LaTeXcombine::Pickup->new();

Returns a new pickup object.

=cut

sub new {
    my $class = shift;
    
    my $self = {
        %fields,
        _errStr => '',
    };
    
    Tarp::Style->import( map { "Tarp::Style::$_" } qw/ITM ITM::NLR/ );
    $self->{style} = Tarp::Style->new();
    bless $self, $class;
    return $self;
}

=head2 fileID

    $id = $p->fileID();
    $p->fileID( $id );

Sets or gets the pickup file ID.

=cut

=head2 check

    $ok = $file->check();

Checks additional arguments given to LaTexCombine::instruction().  By default
Checks that the pickup exercise is an exercise string.

=cut

sub check {
    my $self = shift;
    my $pkEx = shift;
    return $self->_error( "'$pkEx' is not an exercise string")
        unless $self->style()->m( "itemString", $pkEx );
    1;
}

sub _error {
    my $self = shift;
    $self->{_errStr} = shift;
    '';
}

=head2 errStr

    $pk->errStr();

Retrieves the error string.

=cut

sub errStr {
    my $self = shift;
    return $self->{_errStr};
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/ ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;
