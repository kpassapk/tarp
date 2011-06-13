package Tarp::GenTex::MSPlacer;

=head1 NAME

Tarp::GenTex::MSPlacer - Replace $MASTER$ with master number

=head1 SYNOPSIS

    # Loads line buffer
    $exm = Tarp::Itexam->new(...);

    $msp = Tarp::MSPlacer->new( "master", $exm );
    
    # Keys must be the exercises in the file being examined
    $msp->masters({
        01a => "00001",
        01b => "00002",
        ...
    });

    # Replacements are made here, since this method calls our value() method.
    $exm->extractAttributes();
    
    # Set up output file (could be IO::Wrap as well )
    $io = IO::File->new();
    
    # ... set up $io

    # Create output file
    $exm->printLineBuffer( $io );

=head1 DESCRIPTION

This is an C<Itexam> attribute that replaces occurrences of C<$MASTER$>
with a master number.

=cut

use base qw/Tarp::Itexam::Attribute/;

use strict;
use Carp qw/croak/;

my %fields = (
    masters => undef,
);

=head2 new

    $exm = Tarp::Itexam->new(...);
    $msp = Tarp::MSPlacer->new( "master", $exm );

Creates a new MSPlacer attribute for $exm.  The value of this attribute is
the master number set through masters() for each exercise.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    @{$self}{ keys %fields } = values %fields;
    bless $self, $class;
    return $self;
}

=head2 masters

    $msp->masters({
        01a => "00001",
        01b => "00002",
        ...
    });

Sets the masters numbers to replace C<$MASTER$> with, one for each item.
The items must be the same as those in the file that the parent
Itexam is to read using extractAttributes, otherwise this last method
will not succeed.

=head2 value

    $msp->value() (called by Tarp::Itexam::extractAttributes())

Returns the master number for this item set using the L</masters> method.
If L</masters> has not been called, or if there is no master for the exercise
whose attributes are currently being determined, an exception is raised.  For
non-leaf exercises, returns the string C<"n/a">.

This method also substitutes C<$MASTER$> (if it exists in the exercise buffer)
with the master number.

=cut

sub value {
    my $self = shift;
    my $args = shift;
    
    my $masters = $self->masters();
    
    my ( $itemString, $isLeaf, $exBuffer )
        = @{$args}{qw/itemString isLeaf exBuffer/};

    croak "No master values have been set for this attribute using the masters() " ,
          "method, stopped" unless $masters;

    return "n/a" unless $isLeaf;
    
    my $master = $masters->{$itemString}
        or croak "No master for item '$itemString', stopped";

    # Search for $MASTER$ and replace with the correct value.
    
    for ( my $i = 0; $i < @$exBuffer; $i++ ) {
        $exBuffer->[$i] =~ s/\$MASTER\$/$master/g;
    }
    
    return $master;
}

1;