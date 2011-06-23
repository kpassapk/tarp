package Tarp::LaTeXcombine;

use strict;
use warnings;

=head1 NAME

Tarp::LaTeXcombine - combine .tex files into a .chunk and .skel file.

=head1 VERSION

Version 0.994

=cut

our $VERSION = '0.994';

=head1 SYNOPSIS
    
    use Tarp::LaTeXcombine;
    
    $f = Tarp::LaTeXcombine->new();
    
    my $f = Tarp::LaTeXcombine->new();
    $f->style()->load( "in.tas" ) or die $f->style()->errStr();

    $f->instruction( qw/01a foo 01a/ );
    $f->instruction( qw/01b foo 01b/ );
    $f->instruction( qw/01c bar 01c/ );

    my $foo = Tarp::LaTeXcombine::PickupFile->new( "foo.tex" );
    
    # bar content is generated on the fly
    my $bar = Tarp::LaTeXcombine::VirtualPickup->new();
    
    # load foo.tex and get chunk and skel data
    $f->combine( foo => $foo, bar => $bar );

    my $out = IO::File->new();

    $out->open( ">chunks.tex" )
        or die "Could not open chunks.txt for writing: $!, stopped";

    $f->printChunks( $out );

=head1 DESCRIPTION

This module uses an instruction list which contains calls to exercises contained
in one or more pickup files and copies the contents of these exercises over into
a single file. Instead of individually copying over every exercise, contiguous
exercises are copied over in one go. This is done in an attempt to preserve
original formatting contained in the source file(s).

A group of exercises that are copied over in one go are called "chunks." This is
why the new file into which exercises are copied into is called a "chunk" file.
In order to turn a .chunk file into a .tex file, it needs to be merged with a
skeleton (.skel) file which is also produced by LaTeXcombine.  This can be done
with the L<Tarp::GenTex> module.

The grouping of exercises into chunks prior to copying them over is done in two
ways: collapsing the instruction list and grouping contigous exercises. In the
former, whenever a set of pickup instructions references all of a pickup
problem's parts and subparts in a one-to-one fashion, the instructions are
replaced with a single instruction that pulls in the corresponding zero level
exercise. In the latter, whenever pickup instructions reference contiguous
exercises, these are grouped together into the same chunk. Both of these steps
are performed in the combine() method. Additional details about both of these
techniques follow.

=head2 Collapsing the Pickup List

In most cases it is likely that all parts and subparts of a problem will be
copied over from the same source problem.  In this case, the original pickup
instructions can be simplified, or "collapsed", into a single instruction for
the top level problem.  For example,

    01a foo 01a
    01b foo 01b
    01c foo 01c

can be replaced with

    01 foo 01.

See the "Collapsible problems" pdf file included in the Docs directory for classes
of collapsible and non collapsible problems.

=head2 Grouping Contiguous Exercises

Based on the exercises that have been supplied using L</instruction>(), the
combine() method gets "chunks" of contiguous input .  These can be queried using
C<printChunks>.  Pickup instructions are examined sequentially; the algorithm
determines whether each instruction is picking up an exercise that is
contiguous with the one in the previous instruction.  An instruction is
contiguous if all of the following are true:

=over

=item *

It is not virtual

=item *

The previous instruction is not virtual

=item *

The level is the same as the pickup level

=item *

The condition above is true for the previous instruction (if any)

=item *

The pickup file ID is the same as in the previous instruction (if any)

=item *

The pickup exercise is sequential with the previous exercise, as
determined by LaTeXtract

=back

=cut

use Carp;
use Tarp::Style;
use Tarp::GenSkel;

use IO::File;

our $AUTOLOAD;
my %fields = (
    preambleFrom    => '',
    dumpMatches     => '',
    chunkData       => undef, # Chunk data as array [ exFrom, exTo ]
);

=head1 METHODS

=head2 new

    $f = Tarp::LaTeXcombine->new();

Initializes a new C<LaTeXcombine> object. The following flags are available
through accessor methods, for example:

    $f->dumpMatches( 1 );
    $yes = $f->dumpMatches();

=over

=item preambleFrom

File ID to pick up preamble from.  If left undefined, will pick up from the last
pickup file given to combine(), sorted alphabetically.  

=item dumpMatches

If true, will dump match information to matches-$ID$.txt after loading the $ID$
pickup file in L<combine>().

=back

The following style plugins are imported by LaTeXcombine:

=over

=item *

Tarp::Style::ITM, Tarp::Style::ITM::NLR

=item *

Tarp::LaTeXtract::Style

=item *

Tarp::MasterAlloc::Style

=item *

Tarp::GenSkel::Style
    
=back


=cut

sub new {
    my $class = shift;
    return if @_;

    Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
    Tarp::Style->import( "Tarp::LaTeXtract::Style" );
    Tarp::Style->import( "Tarp::MasterAlloc::Style" );
    Tarp::Style->import( "Tarp::GenSkel::Style" );
    
    my $self = {
        %fields,
        pkInstructions  => {},  # Pickup Instructions, ex => [ pkFile, pkEx ]
    
        collectedPkLines => [], # Lines collected from input files
    
        _style             => Tarp::Style->new(),
        _START_DELIMITER => 'CHUNK_START',
        _END_DELIMITER   => 'CHUNK_END'
    };
    
    $self->{chunkData} = [];
    bless $self, $class;
    return $self;
}

=head2 instruction

    $i = $f->instruction( "01a" );
    $f->instruction( "01a", PKFILE );
    $f->instruction( "01a", PKFILE, PKEX );    

Sets or gets the pickup instruction for an exercise string ITM. A pickup
instruction is an array with the first element as the pickup file and the second
element an optional pickup exercise.

=cut

sub instruction {
    my $self   = shift;
    my $newEx  = shift;
    
    if ( @_ ) {
        my $pkFile = shift;
        my $pkEx = shift;
        
        return $self->{pkInstructions}{ $newEx } = [ $pkFile, $pkEx, @_ ];
    } else {
        return $self->{pkInstructions}{ $newEx };
    }
}

=head2 instructions

    %is = $cmb->instructions();

Returns a hashref with all the pickup instructions given using addInstruction(),
 keyed by the new exercise.

=cut

sub instructions {
    my $self = shift;
    return %{$self->{pkInstructions}};
}

=head2 collapsedInstructions

my %ins = $cmb->collapsedInstructions( %pickups );

Returns a hash that is like instructions(), but with all of the calls to
parts and subparts of a problem that are complete and one-to-one being replaced
with a single call to the corresponding zero level exercise.  "Complete" means
that every part and subpart of a problem gets referenced; "one-to-one" means
that, except for the zero level problem number itself, all parts and subparts
are referenced in the same order. See "CollapsibleProblems.pdf" in the Docs
folder of the Tarp Toolkit distribution for more infrormation.

=cut

sub collapsedInstructions {
    my $self = shift;
    my %pickups = @_;
    
    $self->_checkInstructions( %pickups );
    
    while ( my ( $ID, $obj ) = each %pickups ) {
        next if $obj->isVirtual();
        my $listData = $obj->data();
        croak "'$ID' pickup file not loaded or contains no exercises, stopped"
            unless defined $listData && keys %$listData;
    }
    
    my $_style = $self->{_style};

    my $zl = sub {
        my $ex = shift;
        my $itemStack = $_style->itemStack( $ex );
        my $zeroLev = $_style->itemString( [ shift @$itemStack ] );
       $zeroLev;
    };
    
    my %ins = %{$self->{pkInstructions}};
    
    my %collapsible;
    
    # Collapsible zero level problems are 1:1

    # A zero level exercise is 1:1 if:
    # 1 No part and subpart, if any, calls a virtual pickup file.
    # 2 Every part and subpart comes from the same pickupfile & problem number
    # 3 Except for level zero, every part and subpart is the same as the one
    #   being picked up from (e.g. 02aiv and 01aiv, but not 02aiv and 02av).
    # 4 All parts and subparts of each pickup problem are referenced by the
    #   same problem.
    
    # Collapsible zero level problems are complete

    # A zero level problem is complete if:    
    # 5 All parts and subparts are referenced.
    
    # Numbers 1, 2, and 3 are evaluated by iterating over the pickup instructions.
    # Numbers 4 and 5 are evaluated by iterating over each pickup file.
    
    my $lastZeroLev;
    my $lastZeroLevPk;
    my $lastPkFileID;
    
    my @instructions = $_style->sort( keys %ins );
    
    # For numbers 1, 2, and 3
    
    INST: foreach my $ex ( @instructions ) {
        my $pkData = $ins{$ex};
        my ( $pkFileID, $pkEx ) = @$pkData;
        my $pkObj = $pickups{$pkFileID};
        
        my $itemStack = $_style->itemStack( $ex );
        my $zeroLev = $_style->itemString( [ shift @$itemStack ] );

        # (1) Is the reference to a virtual pickup?
        if ( $pkObj->isVirtual() ) {
            $collapsible{$zeroLev} = '';
            $lastZeroLevPk = '';
        } else {
            $collapsible{$zeroLev} = 1
            unless exists $collapsible{$zeroLev};

            # Set the "pickedUp" attribute in the
            # corresponding pickup file.

            my $listData = $pkObj->data();
            $listData->{$pkEx}{pickedUp} = $ex;
 
            my $pkExStack  = $_style->itemStack( $pkEx );    
            my $zeroLevPk = $_style->itemString( [ shift @$pkExStack ] );

            # (2) Do all parts & subparts come from the same file & problem?
            
            if ( $lastZeroLev && $zeroLev eq $lastZeroLev ) {
                $collapsible{$zeroLev} = ''
                    unless $pkFileID eq $lastPkFileID &&
                           $zeroLevPk eq $lastZeroLevPk;
            }
            
            # (3) Is the rest of the problem the same, bar level zero?
            # For zero level problems, comparing two empty strings
            
            $collapsible{$zeroLev} = ''
                unless "@$itemStack" eq "@$pkExStack";
            
            $lastZeroLevPk = $zeroLevPk;
        }
        $lastZeroLev = $zeroLev;
        $lastPkFileID = $pkFileID;
    } # INST loop
    
    # For numbers 4 and 5
    PKFILE: while ( my ( $pkFileID, $pkObj ) = each %pickups ) {
        next PKFILE if $pkObj->isVirtual();
        $lastZeroLev = '';
        $lastZeroLevPk = '';
        my %listData = %{$pkObj->data()};
        my @exDataSorted = $_style->sort( keys %listData );
        ITM: foreach my $pkEx ( @exDataSorted ) {
            my $attrs = $listData{$pkEx};

            my $pkExStack  = $_style->itemStack( $pkEx );
            my $zeroLevPk = $_style->itemString( [ shift @$pkExStack ] );

            if ( $attrs->{pickedUp} ) {

                my $itemStack = $_style->itemStack( $attrs->{pickedUp} );
                my $zeroLev = $_style->itemString( [ shift @$itemStack ]);
    
                # (4) Is every pickup part and subpart called by the same problem?
                if ( $lastZeroLevPk && $lastZeroLevPk eq $zeroLevPk ) {
                    if ( $zeroLev ne $lastZeroLev ) {
                        $collapsible{$lastZeroLev} = ''
                            if $lastZeroLev;
                        $collapsible{$zeroLev} = ''
                    }
                }
                $lastZeroLev = $zeroLev;
            } else {
                if ( $lastZeroLevPk && $lastZeroLevPk eq $zeroLevPk ) {
                    $collapsible{$lastZeroLev} = ''
                        if $lastZeroLev;
                } else {
                    $lastZeroLev = '';
                }
            }
            $lastZeroLevPk = $zeroLevPk;
        } # ITM loop
    } # PKFILE loop
    
    # Now %collapsible has the pickup exercises that are
    # to be picked up whole.
    
    # For all children of collapsible exercises,
    # replace entries in the exercise records with a single ref
    # to the zero level exercise.

    my %collapsedInstructions;

    INST: while ( my ( $ex, $pkData ) = each %ins ) {
        my ( $pkFileID, $pkEx, @args ) = @$pkData;

        my $zeroLev = &$zl( $ex );

        if ( $collapsible{ $zeroLev } ) {
            my $zeroLevPk = &$zl( $pkEx );
            $collapsedInstructions{$zeroLev} = [ $pkFileID, $zeroLevPk, @args ];
        } else {
            $collapsedInstructions{$ex} = $pkData;
        }

    } # INST loop
    
    return %collapsedInstructions;
}

=head2 clear

    $ltx->clear();

Clears all pickup instructions.

=cut

sub clear {
    my $self = shift;
    $self->{pkInstructions} = {};
}

=head2 combine

    $c->combine(
        "file1" => $fileObj1,
        "file2" => $fileObj2,
        ...
    );

Does the work of combining the various LaTeX files.  The steps for doing this
are as follows.  First, a check is performed to determine whether all required
pickup files have been supplied using L<pickup>().  If files are missing,
an exception is raised.  Connectivity between pickup instructions is then
verified.  If possible, the pickup instructions are collapsed into fewer
equivalent instructions in the case that all parts and subparts of a pickup
exercise are referenced in order (see above).  Chunks of contiguous input are
then found.  Finally, lines from each of the pickup files are collected.  These
can be printed using the printChunks() method.

=cut

sub combine {
    my $self = shift;
    my %pickups = @_;
    
    my $usage = "usage: combine( %pickups";
    confess "check $usage )" unless keys %pickups;
    
    my $preFrom = $self->{preambleFrom};
    if ( ! $preFrom ) {
        ( $preFrom ) = reverse sort keys %pickups;
    }

    # Load the pickups
    while ( my ( $ID, $obj ) = each %pickups ) {
        next if $obj->isVirtual();
        $obj->style( $self->style() );
        $obj->load();
            if ( $self->{dumpMatches} ) {
                my $io = IO::File->new();
                $io->open( ">$ID-matches.txt" )
                    or die "Could not open $ID-matches.txt for writing: $!";
                $obj->dumpMatches( $io );
            }
    }

    my %collapsed = $self->collapsedInstructions( %pickups );    
    $self->_getChunks( \%pickups, \%collapsed );
    $self->_collectPickupLines( \%pickups, \%collapsed, $preFrom  );
}

=head2 printChunks

    $cmb->printChunks( $io );

Prints contents of all chunks to $io.

=cut

sub printChunks {
    my $self = shift;
    my $io = shift;
    
    # for each collected pickup bunch of lines,
    # print a macro before and after.
    
    foreach my $cLines ( @{$self->{collectedPkLines}}) {
        print $io $self->{_START_DELIMITER} . "\n";
        print $io $cLines;
        print $io $self->{_END_DELIMITER} . "\n\n";
    }
}

=head2 printSkel

    $cmb->printSkel( $io );

Prints skeleton to $io.

=cut

sub printSkel {
    my $self = shift;
    my $io = shift;

    my $sg = Tarp::GenSkel->new();
    $sg->style( $self->style() );
    foreach my $chunk ( @{$self->{chunkData}} ) {
        $sg->addChunk( $chunk->[0], $chunk->[1] );
    }
    
    $sg->printSkel( $io );
}

=head2 style

    $ltx->style( $sty );
    $sty = $ltx->style();

Sets the style of this object.

=cut

sub style {
    my $self = shift;
    if ( @_ ) {
        croak "Argument must be a 'Tarp::Style' ref"
            unless ref $_[0] eq "Tarp::Style";
        $self->{_style} = shift;
    } else {
        return $self->{_style};
    }
}

=head2 gotMissingFileIDs

    (not user callable)

Croaks because of missing file IDs.

=cut

sub gotMissingFileIDs {
    my $self = shift;
    my @mid = @_;
    
    my $mpr = join ", ", @mid;

    croak "Missing file ID(s): $mpr; stopped";
}

sub _checkInstructions {
    my $self = shift;
    my %pickups = @_;
    # Check that all of the exercises are leaves

    # Do we have the pickup files we need?
    my %ins = $self->instructions();
    my %req = map { $ins{$_}->[0] => 1 } keys %ins;
    my @mid = grep { ! exists $pickups{$_} } keys %req;
    
    # Report
    $self->gotMissingFileIDs ( @mid ) if @mid;    
    
    my @ins = $self->style()->sort( keys %ins );

    my $lastEx = '';
    
    INST: foreach my $ex ( @ins ) {

        my $pkData = $ins{$ex};

        my ( $ID, $pkEx, @args ) = @$pkData;
        my $pkObj = $pickups{$ID};
        
        my $equiv = $self->style()->itemStack( $ex );

        pop @$equiv
            while ( @$equiv > 1 && $equiv->[-1] == 1 );
        
        if ( $lastEx && ! $self->style()->isInOrder( $lastEx, $self->style()->itemString( $equiv ) ) ) {
            croak "Gap in input exercises between $lastEx and $ex, stopped";
        }

        if ( ! $pkObj->check( $pkEx, @args ) ) {
            croak "'$ID' pickup instruction error: " . $pkObj->errStr() . " (required for '$ex'), stopped";
        }
        $lastEx = $ex;
    }
}

sub _getChunks {
    my $self = shift;
    my $pickups = shift;
    my $instructions = shift;
    
    my $_style = $self->{_style};

    my @exs = $_style->sort( keys %$instructions );
    
    my $lastPkFileID = undef;
    my $lastPkObj    = undef;
    my $lastEx       = undef;
    my $lastPkEx     = undef;
    
    my @chunkData = ();
    
    # The first chunk starts with the first pickup exercise.
    push( @chunkData, [ $exs[0], undef ] );

    # For the remaining exercises, determine whether
    # to continue current chunk or start a new one.
        
    for ( my $i = 0; $i < @exs; $i++ ) {    
        my $ex = $exs[ $i ];
        my $instruction = $instructions->{$ex};
        my ( $pkFileID, $pkEx ) = @$instruction;
        my $pkObj = $pickups->{$pkFileID};
        
        die "$pkEx not found in $pkFileID, stopped"
            unless  $pkObj->isVirtual() ||
                    $pkObj->exists( $pkEx );
        if ( $i > 0 ) {
            my $newChunk = 1;
            # Virtual pickups are never contiguous
            unless ( $pkObj->isVirtual() ||
                     $lastPkObj->isVirtual() ) {
#                my $lev   = $_style->exLevel( $ex );
#                my $pkLev = $_style->exLevel( $pkEx );
#                my $lastLev = $_style->exLevel( $lastEx );
#                my $lastPkLev = $_style->exLevel( $lastPkEx );

                my $lev   = @{ $_style->itemStack( $ex ) } - 1;
                my $pkLev = @{ $_style->itemStack( $pkEx ) } - 1;
                my $lastLev = @{ $_style->itemStack( $lastEx ) } - 1;
                my $lastPkLev = @{ $_style->itemStack( $lastPkEx ) } - 1;

                $newChunk = 0
                    if ( $lastLev  == $lastPkLev     &&
                         $lev      == $pkLev         &&
                         $pkFileID eq $lastPkFileID  &&
                         $pkObj->isSequential( $lastPkEx, $pkEx ) );
            }
            if ( $newChunk ) {
                # Input is not sequential.  New chunk.
                $chunkData[-1][1] = $lastEx;
                push( @chunkData, [ $ex, undef ] );
            }
        }
        $lastPkFileID = $pkFileID;
        $lastPkObj    = $pkObj;
        $lastPkEx     = $pkEx;
        $lastEx       = $ex;
    }
    
    # Wrap up the chunk list with the last exercise.
    $chunkData[-1][1] = $lastEx;
    
    $self->{chunkData} = \@chunkData;
}

sub _collectPickupLines {
    my $self = shift;
    my $pickups = shift;
    my $instructions = shift;
    my $preambleFrom = shift;
    
    # For each chunk, go to the corresponding
    # file indicated by the first number in the range
    # and print out the line numbers in that range.
    
    my $chunkData = $self->{chunkData};
    
    my @collectedPkLines;
    
    # Put preamble into first chunk.
    my $preambleObj = $pickups->{$preambleFrom};
    push( @collectedPkLines, join( '', @{$preambleObj->preambleBuffer()}));
    
    foreach my $chunk ( @$chunkData ) {
        my $neFrom = $instructions->{ $chunk->[0] }; # new edition From
        my $neTo   = $instructions->{ $chunk->[1] }; # new edition To
        my ( $pkFileID ) = @$neFrom; # Should be the same as $neTo->{pkFileID}
        my $pkFileObj    = $pickups->{$pkFileID};
        
        my $pkFrom = $neFrom->[1];
        my $pkTo   = $neTo->[1];
        my $lines = $pkFileObj->exRangeBuffer( $pkFrom, $pkTo );
        shift @$lines;
        push( @collectedPkLines, join( '', @$lines ) );
    }
    $self->{collectedPkLines} = \@collectedPkLines;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{$name} && $name =~ /^[a-z]/ ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::LaTeXcombine

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::LaTeXcombine