package Tarp::Itexam::Attribute::Line;

=head1 NAME

Tarp::PullSolns::Attribute::Line - An attribute for an exercise's line number

=head1 SYNOPSIS

    use Tarp::Itexam::LineAttribute;
    
    $ITM = Tarp::Itexam->new( ... );
    $passThru = Tarp::Itexam::LineAttribute->new( "foo", $ITM );

=head2 DESCRIPTION

An Itexam::Attribute that returns the starting line number for each
exercise.

=cut

use warnings;
use strict;

use base qw/ Tarp::Itexam::Attribute /;

=head2 new

    $ITM = Tarp::Itexam->new( ... );
    Tarp::Itexam::LineAttribute->new( "foo", $ITM );

Creates a new line number attribute.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    return bless $self, $class;
}

=head2 value

    (not user callable)

Returns the line number for the current exercise.

=cut

sub value {
    my $self = shift;
    my $args = shift;
    return $args->{exLine};
}

1;