package Tarp::Counter::Numeric;

=head1 NAME

Tarp::Counter::Numeric - A numeric counter

=head1 SYNOPSIS

    use Tarp::Counter::Numeric;
    
    $ctr = Tarp::Counter::Numeric->new();
    
    $str = $ctr->fwdTex( 1 ); # $i contains "1"
    $str = $ctr->fwdStr( 1 ); # $i contains "01"
    
    $i = $ctr->revTex( "1" ); # $i contains 1
    $i = $ctr->revStr( "01" ); # $i contains 1

=cut

use base qw/ Tarp::Counter /;

use strict;
use warnings;

=head1 METHODS

=head2 new

    $ctr = Tarp::Counter::FormatBase->new();

Creates a new counter.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    $self->{matchTex} = '[1-9]\d{0,2}';
    $self->{matchStr} = '\d\d\d?';
    bless $self, $class;
    return $self;
}

=head2 fwdTex

    $symbol = $c->fwdTex( $int );

Translates from an integer to a string in LaTeX context.

=cut

sub fwdTex {
    my $class = shift;
    my $i = shift;
    return $i;
}

=head2 revTex

    $int = $c->revTex( $symbol );

Translates a string in LaTeX context to an integer.

=cut

sub revTex {
    my $class = shift;
    my $i = shift;
    return int( $i );
}

=head2 fwdStr

    $str = $ctr->fwdStr( $int );

Converts from integer to stringified exercise.

=cut

sub fwdStr {
    my $class = shift;
    my $i = shift;
    return $i if length $i > 1;
    return sprintf( "%0*d", 2, $i );
}

=head2 revStr

    $int = $ctr->revStr( $str );

Converts from stringified exercise to integer.

=cut

sub revStr {
    my $class = shift;
    my $i = shift;
    return int( $i );
}

1;