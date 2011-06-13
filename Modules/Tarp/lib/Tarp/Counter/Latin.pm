package Tarp::Counter::Latin;

=head1 NAME

Tarp::Counter::Latin - An alphanumeric counter (a,b,c...)

=cut

use base qw/ Tarp::Counter /;

use strict;
use warnings;

=head1 METHODS

=head2 new

    $ctr = Tarp::Counter::Latin->new();

Creates a new counter.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    my @fwd = qw/ dummy a b c d e f g h i j k l m n o p q r s t u v w x y z /;

    my %rev;
    @rev{ @fwd } = ( 0 .. 27 );

    $self->{fwd} = \@fwd;
    $self->{rev} = \%rev;
    $self->{matchTex} = '[a-z]';
    $self->{matchStr} = '[a-z]';
    
    bless $self, $class;
    return $self;
}

1;