package Tarp::Counter;

=head1 NAME

Tarp::Counter - Abstract base class for counter types.

=head1 SYNOPSIS

    use Tarp::Counter;

=head1 DESCRIPTION

A counter maps some sort of symbol to an integral value.

=cut

use strict;
use warnings;

=head2 new

    $ctr = Tarp::Counter->new();

Creates a new counter.

=cut

sub new {
    my $class = shift;
    my $self = {
        fwd => [],
        rev => {},
        matchStr => undef,
        matchTex => undef
    };
    
    bless $self, $class;
    return $self;
}

=head2 fwdTex

    $symbol = $c->fwdTex( $int );

Translates from an integer to a string in LaTeX context.

=cut

sub fwdTex {
    my $self = shift;
    my $i = shift;
    return $self->{fwd}[ $i ];
}

=head2 revTex

    $int = $c->revTex( $symbol );

Translates a string in LaTeX context to an integer.

=cut

sub revTex {
    my $self = shift;
    my $az = shift;
    return $self->{rev}{ $az }
}

=head2 fwdStr

    $str = $ctr->fwdStr( $int );

Converts from integer to stringified exercise.

=cut

sub fwdStr {
    my $self = shift;    
    return $self->fwdTex( shift );
}

=head2 revStr

    $int = $ctr->revStr( $str );

Converts from stringified exercise to integer.

=cut

sub revStr {
    my $self = shift;    
    return $self->revTex( shift );
}

=head2 matchStr

    $re = $ctr->matchStr();

Returns the regular expression that matches the stringified counter.

=cut

sub matchStr {
    my $self = shift;
    return $self->{matchStr};
}

=head2 matchTex

    $re = $ctr->matchTex();

Returns the regular expression that matches the counter in LaTeX context.

=cut

sub matchTex {
    my $self = shift;
    return $self->{matchTex};
}

1;