package _PickedUp_Attr_;

use base Tarp::Itexam::Attribute;

sub new {
    my $class = shift;
    return bless $class->SUPER::new( @_ ), $class;
}

sub value { '' }

package Tarp::LaTeXcombine::PickupFile;

use base qw/Tarp::LaTeXcombine::Pickup/;

=head1 NAME

Tarp::LaTeXcombine::PickupFile - pick up exs. or preamble from a file

=head1 SYNOPSIS

    use Tarp::LaTeXcombine::PickupFile;
    
    my $pk = Tarp::LaTeXcombine::PickupFile->new();
    $pk->TEXfile( $TEXfile );
    $pk->load();
    
=head1 DESCRIPTION

This class is used to pick up exercises from a LaTeX file, which must
contain a list of exercises parsable by LaTeXtract.

=cut

use strict;
use Tarp::Itexam;
use Tarp::Itexam::Attribute::Master;

use Carp;

my %fields = (
    TEXfile     => '',
    activeSeq   => undef,
);

=head2 new

    $pkf = Tarp::PickupFile->new( $file );
    $pkf = Tarp::PickupFile->new( $file, $seq );

Creates a new pickup file object on '$file'.  If '$seq' is speicified, uses that
numbering sequence in $file; otherwise, it the sequence is determined automatically.

=cut

sub new {
    my $class = shift;
    my $TEXfile = shift;
    my $activeSeq = shift;
    
    my $self = $class->SUPER::new( @_ );

    @{$self}{keys %fields} = values %fields;
    $self->{TEXfile} = $TEXfile;
    $self->{activeSeq} = $activeSeq;
    $self->{_EXDATA} = undef;
    
    my $exm = Tarp::Itexam->new;
    $exm->style( $self->style() );
    my $pk = _PickedUp_Attr_->new( "pickedUp", $exm );
    my $master = Tarp::Itexam::Attribute::Master->new( "master", $exm );
       $master->startTag( "TCIMACRO" );
       $master->endTag( "EndExpansion" );
    
    $exm->maxLevel( 2 );
    $self->{_EXM} = $exm;
    $self->{_masterAttr} = $master;
    
    bless $self, $class;   
    return $self;
}

=head2 isVirtual

    $pkf->isVirtual();

Returns zero.

=cut

sub isVirtual {0}

=head2 load

    $pkf->load();

Loads the pickup file. First, the file is read into a buffer and stripped of
certain variables. Then the active sequence is guessed if it has not been
specified already. 

The filename can be relative or absolute. The numbering sequence in the LaTeX
file to pick exercises can be specified explicitly or determined automatically
as follows:

=over

=item *

If the file has one numbering sequence, that one (C<0>) is used.

=item *

If the file has more than one numbering sequence, but only one has exercises,
that one is used.

=back

If the file has more than one numbering sequence, and more than one sequence
contains exercises, the sequence must be specified explicitly.

=cut

sub load {
    my $self = shift;

    my $TEXfile = $self->{TEXfile};
    my $activeSeq = $self->{activeSeq};
    
    my $exm = $self->{_EXM};
    
    # Strip all variables except for MASTER, because we want to do sanity
    # check later with the master number in the pickup list and leave some
    # way to identify an exercise in the chunk file if necessary.
    
    my @stripVars = grep { $_ ne "MASTER" } $self->style()->vars();
    $exm->stripVariables( [ @stripVars ] );

    my @refFormats = $exm->style()->interpolate( "masterRef" );
    $self->{_masterAttr}->refFormats( \@refFormats );
    
    $exm->extractAttributes( $TEXfile )
        or croak $exm->errStr();
    
    # Try and determine active sequence if not already specified
    my $seqCount = $exm->seqCount();
    
    if ( defined $activeSeq ) {
        # Make sure sequence exists and has exercises in it.
        croak "Sequence $activeSeq does not exist in '$TEXfile', stopped"
            if ( $activeSeq >= $seqCount );
        
        croak "Sequence '$activeSeq' contains no exercises, stoppped"
            unless ( keys %{ $exm->exData( $activeSeq ) } > 0 );
        
    } elsif ( $seqCount > 1 ) {
        # Try and guess active sequence if there is only one sequence
        # with exercises.
        my $iact;
        
        for ( my $iseq = 0; $iseq < $seqCount; $iseq++ ) {
            if ( keys %{ $exm->exData( $iseq ) } > 0 ) {
                croak "'$TEXfile' has more than one sequence with exercises, stopped"
                    if defined $iact;
                $iact = $iseq; #Save
            }
        }
        
        # Many sequences but only one with exercises.  Use this one.
        $activeSeq = $iact;
        
    } else {
        # One sequence. Use it.
        $activeSeq = 0;
    }
    
    @{$self}{qw/activeSeq _EXDATA/}
        = ( $activeSeq, $exm->data( $activeSeq ) );
}

=head2 masterNumber

    $master = $pkf->masterNumber( "01a" );

Returns the masterID of the specified exercise.

=cut

sub masterNumber {
    my $self = shift;
    my $ex = shift;
    
    my ( $activeSeq , $_EXM )
        = @{$self}{qw/activeSeq _EXM/};
    
    my $rec = $_EXM->item( $ex, $activeSeq );

    return $rec->{master};
}

=head2 check

Returns true if the argument contains a 'pkEx' field corresponding to a leaf
exercise that exists in the active sequence.

=cut

sub check {
    my $self = shift;
    my $pkEx = shift;

    return unless $self->SUPER::check( $pkEx, @_ );    
    return $self->_error( "'$pkEx' not found" )
        unless $self->exists( $pkEx );
    return $self->_error( "'$pkEx' contains parts or subparts" )
        unless $self->isLeaf( $pkEx );
    1;
}

=head2 data

    $pkf->data();

Returns Itexam's exercise data for the active sequence (a hashref)

See also L<Tarp::Itexam/listData>

=cut

sub data {
    my $self = shift;
    return $self->{_EXDATA};
}

=head2 exerciseBuffer

    $buf = $pkf->exerciseBuffer( "01a" );

Returns a line buffer containing the lines belonging to the specified exercise.

=cut

sub exerciseBuffer {
    my $self = shift;
    my $ex   = shift;
    
    my ( $activeSeq , $_EXM )
        = @{$self}{qw/activeSeq _EXM/};
    
    return $_EXM->exerciseBuffer( $ex, $activeSeq );
}

=head2 exRangeBuffer

    $buf = $pkf->exRangeBuffer( $firstEx, $lastEx );

Returns buffer lines of all the exercises between $firstEx and $lastEx
in the active sequence of this file.  Although the order of $firstEx and
$lastEx does not matter, they must both exist in the active sequence of this
file.

=cut

sub exRangeBuffer {
    my $self = shift;
    my $firstEx = shift;
    my $lastEx = shift;

    my ( $activeSeq, $_EXM )
        = @{$self}{qw/activeSeq _EXM/};

    return $_EXM->exRangeBuffer( $firstEx, $lastEx, $activeSeq );    
}

=head2 isSequential

    $yes = $f->isSequential( "01", "02" );
    $no = $f->isSequential( "01", "03" );

Returns C<1> if the first and second arguments are sequential in the
active sequence of this file, and an empty string otherwise.

=cut

sub isSequential {
    my $self = shift;
    my $first = shift;
    my $second = shift;
    
    my ( $activeSeq , $_EXM )
        = @{$self}{qw/activeSeq _EXM/};
    
    return $_EXM->isSequential( $first, $second, $activeSeq );
}

=head2 isLeaf

    $yes = $pkf->isLeaf( "01a" );

Returns C<1> if the specified exercise is a leaf (has no children).

=cut

sub isLeaf {
    my $self = shift;
    my $ex = shift;
    
    my ( $activeSeq, $_EXM  )
        = @{$self}{qw/activeSeq _EXM/};
    
    return $_EXM->isLeaf( $ex, $activeSeq );
}

=head2 exists

    $yes = $pkf->exists();
    $yes = $pkf->exists( "01a" );

The first form returns a true value if the pickup file exists on disk.  The
second form returns true if, after load() has been called, the exercise given
as an argument exists in the file's active sequence.

=cut

sub exists {
    my $self = shift;
    my $ex = shift;
    
    my ( $TEXfile, $activeSeq , $_EXM )
        = @{$self}{qw/TEXfile activeSeq _EXM/};
    
    if ( ! defined $ex ) {
        return -e $TEXfile;
    }
    
    return $_EXM->exists( $ex, $activeSeq );
}

=head1 Itexam Wrapper Methods

=over

=item preambleBuffer

=item dumpMatches

=item style

=back

=cut

sub preambleBuffer {
   my $self = shift;
   return $self->{_EXM}->preambleBuffer( @_ );
}

sub dumpMatches {
    my $self = shift;    
    return $self->{_EXM}->dumpMatches ( @_ );
}

sub style {
    my $self = shift;
    my $s = $self->SUPER::style( @_ );
    if ( @_ ) {
        $self->{_EXM}->style( $s );
    }
    return $s;
}

1;
