package Tarp::Itexam::Attribute::Master;

=head1 NAME

Tarp::Itexam::Attribute::Master - Attribute for extracting
MasterIDs, designed for 4c3

=cut

use base qw/ Tarp::Itexam::Attribute /;

use strict;
use warnings;
use Carp;

# use Tarp::MultiLineMatch;

my %fields = (
    startTag    => "TCIMACRO",
    endTag      => "EndExpansion",
);

=head1 METHODS

=head2 new

    MasterNumberAttribute->new( "MasterID", $examiner );

This attribute corresponds to a master number reference within an exercise.
The default macro start and end tags are "TCIMACRO" and "EndExpansion".

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );

    @{$self}{keys %fields} = values %fields;
    
    $self->{_refFormats}  = [ '(\d+)' ];
    
    bless $self, $class;
    return $self;
}

=head2 startTag

    $tag = $msn->startTag();
    $msn->startTag( $tag );

Accessor method for macro start tag (string that marks the beginning of a macro)

=head2 endTag

    $tag = $msn->endTag();
    $msn->endTag( $tag );

Accessor method for end tag (string that ends a macro).

=head2 refFormats

    $f = $msn->refFormats();
    $msn->refFormats( $f );

Accessor method for master reference formats.  This method expects an arrayref
with one or more regular expressions.

=cut

sub refFormats {
    my $self = shift;
    if ( @_ ) {
        confess "check arguments" unless ref $_[0] eq "ARRAY";
        return $self->{_refFormats} = shift;
    } else {
        return $self->{_refFormats};
    }
}

=head2 value

    (not user callable)

Reimplements C<Itexam::Attribute>'s value() function.  Gets a MasterID
number using the following arguments (supplied as a hashref)

    # read-only
        TEXfile         The LaTeX file name being extracted
        exSeq           Numbering sequence (integer)
        itemString        Exercise string
        exLine          Line where the exercise is found
        isLeaf          True if this exercise is a leaf (has no children)
    # read/write
        exBuffer        Line buffer corresponding to the exercise

This function calls the L</getMasterNumber> function, passing on the above
arguments.

=cut

sub value {
    my $self = shift;
    return $self->getMasterNumber( shift );
}

=head2 getMasterNumber

    (not user callable)

Gets the masterID number from an exercise buffer.

If the exercise is not a leaf, "n/a" is returned.

=cut

sub getMasterNumber {
    my $self = shift;
    my $args = shift;
    
    my ( $exBuffer, $itemString, $exLine, $isLeaf )
        = @{$args}{ qw/ exBuffer itemString exLine isLeaf/ };
    
    return "n/a" unless $isLeaf;
    
    my $masterNumber = '';
    
#    my $mm = Tarp::MultiLineMatch->new();
#    $mm->startTag( $self->{startTag} );
#    $mm->endTag( $self->{endTag} );
 
    if ( my @matches = $self->_getRanges( $exBuffer ) ) {
#    if ( $mm->match( $strbuf ) ) {
        # There is at least one macro
        my %masters;
#        my @matches = @{$mm->ranges()};
        
        # Check each macro for masterID refs
        for ( my $im = 0; $im < @matches; $im++ ) {
            my $m = $matches[ $im ];
            my $macroLine = $exLine + $m->[0] - 1;
            
            # Temporary copy of lines in this buffer
            my @macroBuffer = @$exBuffer[ $m->[0]-1 .. $m->[1]-1 ];
            
            # Get masters in this macro
            my %uniqueMasters;
            my @allMasters = $self->refsInMacro({
                # Read-only in subroutine:
                macroBuffer => \@macroBuffer,
                # Replaceable in subroutine:
                unique      => \%uniqueMasters,
            });
            my @uniqueMasters = sort keys %uniqueMasters;

            if ( @uniqueMasters > 1) {
                # Resolve this or die (default)
                $self->gotMacroManyMasters({
                    %$args,
                    # Read-only in subroutine:
                    macroBuffer => \@macroBuffer,
                    macroLine   => $macroLine,
                    allRefs     => \@allMasters,
                    # Replaceable in subroutine:
                    uniqueRefs  => \@uniqueMasters,
                });
                @$exBuffer[ $m->[0]-1 .. $m->[1]-1 ] = @macroBuffer;
            }
            
            if ( @uniqueMasters ) {
                # One or more unique masters: choose the first one.
                if ( exists $masters{$uniqueMasters[0]} ) {
                    # Uh oh, we already had this master in another macro
                    # (unusual, but hey)
                    $self->gotMasterManyMacros({
                        %$args,
                        master => $uniqueMasters[0]
                    });
                } else {
                    $masters{$uniqueMasters[0]} = $im;
                }
            }
        }
        
        # If the program has not died yet (i.e. if calling this method thru a
        # subclass) we could have one of the following:
        # - No masterIDs
        # - A single masterID
        # - More than one masterID, but each one in a separate macro.
        #   (this often happens if we have missed parts in an exercise)
        
        # Call different methods for each of the cases above
        if ( keys( %masters ) ) {
            # At least one master
            if ( keys( %masters) > 1 ) {
                # More than one master
                my @found = keys( %masters );
                
                $self->gotExManyMasters({
                    %$args,
                    masters => \@found,
                });
            }
            # Exactly one: Get its number
            $masterNumber = each( %masters );
            $self->gotExSingleMaster({
                # Read-only in subroutine:
                %$args,
                macros   => \@matches,
                macroIdxWithRef => $masters{$masterNumber},
                # Replaceable in subroutine:
                ref => \$masterNumber,
            });
        } else {
            # No masters found
            $self->gotExSansMaster({
                # Read-only in subroutine:
                %$args,
                macros   => \@matches,
                # Replaceable in subroutine:
                master   => \$masterNumber,
            });
        }
    } else {
        # No macros found
        $self->gotExSansMacro( $args );
    } 

    return $masterNumber;
}

=head2 refsInMacro

    (not user callable)

This function is called by the getMasterNumber method in order to get the master
number from a macro.  The following arguments are provided:

    {
    # Read-only in subroutine:
        macroBuffer => [ARRAYREF]    # The macro buffer
    # Replaceable in subroutine:
        unique      => [HASHREF]     # Replaced with unique masters & occurrence count.
    };

If called in scalar context, returns the number of master number refs found
in macroBuffer, including duplicates.  If called in a list context, returns
the references in the order found, from left to right and top to bottom. 

"unique" gets replaced with a hashref having the master numbers found in the
macro as keys, and the time each was found as values.

=cut

sub refsInMacro {
    my $self = shift;
    my $args = shift;
    
    my @macroBuffer = @{$args->{macroBuffer}};
    my $refFormats = $self->refFormats();
    
    my %unique;
    my @masters;
    
    # Find all references in these formats, even multiple
    # on the same line.
    
    for ( my $i = 0; $i < @macroBuffer; $i++ ) {
        my %msByPos;
        foreach my $fmt_re ( @$refFormats ) {
            my $macroLine = $macroBuffer[$i];
            my $got_match;

            while ( $macroLine =~ /$fmt_re/g ) {
                my $pos = pos $macroLine; # Where in the string the match occurred
                die "refFormat '$fmt_re' does not contain parens capture buffer, stopped"
                    unless defined $1;
                my $msnum = $1;
                
                $msByPos{$pos}  = $msnum;
                $unique{$msnum} = $unique{$msnum} ? $unique{$msnum}++ : 1;
            }
        }
        # Sort numerically
        my @K = sort { $a <=> $b } keys %msByPos;
        foreach my $k ( @K ) {
            push( @masters, $msByPos{$k} );
        }
    }
    
    %{$args->{unique}} = %unique;
    
    return @masters;
}

=head2 gotExSansMacro

    (not user callable)

This function gets called by the C<getMasterNumber> method in the following situation:

=over

=item *

An exercise did not have a macro. 

=back

This method has the same arguments available as the value() method.

=cut

sub gotExSansMacro {
    my $self = shift;
    my $args = shift;
    my ( $TEXfile, $ex, $line ) = @{$args}{qw/TEXfile itemString exLine/};

    die "Exercise $ex contains no macros at $TEXfile line $line.\n";
}

=head2 gotExSansMaster

This function gets called by the C<getMasterNumber> method in the following situation:

The exercise has one or more macros but no master references.

=cut

sub gotExSansMaster {
    my $self = shift;
    my $args = shift;

    my ( $TEXfile, $ex, $line )
        = @{$args}{qw/TEXfile itemString exLine/};
    
    die "Macro(s) in $ex contain no master number refs at $TEXfile line $line.\n";
}

=head2 gotExSingleMaster

    (not user callable)

This function gets called by the C<getMasterNumber> method in the following situation:

=over

=item *

The exercise has one or more macros and a single master reference.

=back

Apart from the arguments given to the value() function, the following are availble:

=over

=item * macros

Arrayref to starting and ending lines of macros in the exercise buffer, relative
to the first line of the exercise buffer.

=item * macroIdxWithRef

Macro index with master reference.

=item * ref

The masterID referenced.

=back

=cut

sub gotExSingleMaster {}

=head2 gotExManyMasters

    (not user callable)

This function gets called by the C<getMasterNumber> method in the following situation:

=over

=item *

The exercise has more than one macro spread across different macros.

=back

Apart from the arguments given to the value() function, the following are availble:

=over

=item * masters

Arrayref containing the unique master numbers found in the exercise.

=back

=cut

sub gotExManyMasters {
    my $self = shift;
    my $args = shift;
    
    my ( $TEXfile, $ex, $line, $masters )
        = @{$args}{qw/TEXfile itemString exLine masters/};
    
    die "Exercise $ex has multiple masters (@$masters) across different macros - " .
        "possibly failed to catch parts or subparts for this exercise? $ex is at $TEXfile line $line.\n";
}

=head2 gotMacroManyMasters

    (not user callable)

This function gets called by the C<getMasterNumber> method in the following situation:

A single macro found with more than one ref to a master number.

Additional fields in arguments:

    # Read-Only:
        macroBuffer => [ARRAYREF]       Lines in the macro, terminating in newline   
        macroLine   => int              Line relative to exercise where macro is found
        allRefs     => [ARRAYREF]       All The macro refs that were found, in order of occurrence.
    # Replaceable in subroutine:
        uniqueRefs  => [ARRAYREF]       Unique master refs (will contain >1 element)

# If function returns, the first value in uniqueRefs is used.

=cut

sub gotMacroManyMasters {
    my $self = shift;
    my $args = shift;
    
    my ( $TEXfile, $ex, $line, $uniqueRefs, $macroLine )
        = @{$args}{qw/TEXfile itemString exLine uniqueRefs macroLine/};

    die "Macro in $ex has multiple master refs (@$uniqueRefs), stopped at $TEXfile line $macroLine.\n";
}

=head2 gotMasterManyMacros

    (not user callable)

This function gets called by the C<getMasterNumber> method in the following situation:

=over

=item *

The same masterID is found in more than one macro within an exercise (unusual)

=back

=cut

sub gotMasterManyMacros {
    my $self = shift;
    my $args = shift;
    
    my ( $TEXfile, $itemString, $exLine, $master )
        = @{$args}{qw/ TEXfile itemString exLine master /};
    
    die "Master $master is found in more than one macro in $itemString, stopped at $TEXfile line $exLine.\n";
}

sub _getRanges {
    my $self = shift;
    my $exb = shift;
    
    my $in = 0;
    my @r = ();
    
    my $l = 1;
    foreach ( @$exb ) {
        if ( /${\( scalar $self->startTag() ) }/ ) {
            push @r, [ $l ];
            $in  = 1;
        }
        if ( /${\( scalar  $self->endTag() ) }/ ) {
            croak "end with no start" unless $in;
            push @{$r[-1]}, $l;
        }
        $l++;
    }
    @r;
}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::PullSolns::MasterNumberAttribute

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut


1;