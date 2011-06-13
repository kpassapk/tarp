package Tarp::Itexam;

=head1 NAME

Tarp::Itexam - get exercise attributes from exercise lists in LaTeX files

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    use Tarp::Itexam;
    
    # Create Examiner with single attribute called "line"
    $ITM = Tarp::Itexam->new();
    
    # Specify an attribute (through subclass)
    Tarp::Itexam::Attribute->new( "foo", $ITM );
    
    $exm->takeAttribute( $exm->attribute( "line" ) );

    # Extract attributes from file.tex:
    $foo->extractAttributes( "file.tex" );
    
    # Get exercise data for sequence 0 (a hashref)
    my $data = $foo->data( 0 );

=head1 DESCRIPTION

The main task of C<Itexam> is to look at the contents of each exercise
in a C<LaTeX> file and determine certain properties, or attributes. Using this
module and an C<Itexam::Attribute> subclass, the user can specify what
is extracted from each exercise and how. An attribute is a single piece of data;
it could be, for example, the length of the exercise in lines, or the presence
of a certain pattern within the exercise. The actual behavior is implementation
dependent.

Apart from determining a single piece of data about each exercise, it is
possible to create an attribute that also performs some very limited editing on
the contents of exercises themselves. This is done through a copy of the LaTeX
file stored in a line buffer. The line buffer is split up into bits
corresponding to each exercise (each bit is called an "exercise buffer"), and
then each C<Itexam::Attribute>'s C<value()> function is called and given this
exercise buffer to determine its respective value. If this function also changes
the buffer, these changes will be reflected in the larger line buffer. However
it is suggested that this editing should be minimal and that any changes made by
one attribute should not affect the value of any other attributes.

When an attribute is created (by using its new() method), it is a child of the
Itexam object given in the constructor. The attribute can be detached by
using the detachAttribute() method, which means it will no longer be used by
the Itexam.

By default, one attribute is created containing each exercise's line number. The
name of this attribute is "line".

=cut

use strict;
use warnings;
use Tarp::LaTeXtract;
use Tarp::Itexam::Attribute::Line;
use Carp;
use Tie::RefHash;

=head1 ENUMERATED TYPES

=head2 ALL_LEVELS

Supplied to C<maxLevel()> accessor method in order to extract all exercise levels. 

=cut

sub ALL_LEVELS { -1 }

our $AUTOLOAD;
my %fields = (
    stripVariables    => 1,
    maxLevel          => Tarp::Itexam::ALL_LEVELS,
    enforceOrder      => '',
    doubleClickable   => '',
    relax             => '',
);

my $Debugging = 0;

=head1 METHODS

=head2 new

    $foo = Tarp::Itexam->new();

Creates a new Itexam object. This method imports Tarp::LaTeXtract::Style,
Tarp::Style::ITM and Tarp::Style::ITM::NLR.

The following flags are available through accessor methods, for example,

    $l = $exm->maxLevel();
    $exm->maxLevel( 2 );

=over

=item stripVariables

If set to a true value, variables in the line buffer will be stripped.
A hashre containing variable names can also be supplied:

    $exm->stripVariables( [ qw/foo bar bat/] );

B<Default: true>.

=item maxLevel

The maximum level exercise level to use.  If set to C<Tarp::Itexam::ALL_LEVELS>,
attributes at all levels will be extracted and available through the C<listData>
method. B<Default: C<Tarp::Itexam::ALL_LEVELS> >

=item enforceOrder

Sets LaTeXtract's C<enforceOrder> option. B<Default: C<false> > 

=item doubleClickable

Sets LaTeXtract's C<doubleClickable> option.  B<Default: C<false> > 

=back

=cut

sub new {
    my $class = shift;
    confess "check usage: Tarp::Itexam->new()" if @_;
    
    my %h;
    tie %h, "Tie::RefHash";
    
    my $self = bless {
        _permitted      => \%fields,
        %fields,
        attributes      => \%h,
        lineBuffer      => [],
        listData          => undef,
        _XTR            => undef,
        _errStr         => '',
    }, $class;

    my $xtr = Tarp::LaTeXtract->new();
    $xtr->maxLevel       ( Tarp::LaTeXtract::ALL_LEVELS );
    $xtr->enforceOrder   ( $fields{enforceOrder}        );
    $xtr->doubleClickable( $fields{doubleClickable}     );
    $self->{_XTR} = $xtr;    

    Tarp::Itexam::Attribute::Line->new( "line", $self );
    return $self;
}

sub _reload {
    my $self = shift;
    my $name = shift;
    
    my ( $enforceOrder, $stripVariables, $doubleClickable, $relax, $_XTR )
        = @{$self}{qw/enforceOrder stripVariables doubleClickable relax _XTR/};

    my %actions = (
        enforceOrder    => sub { $_XTR->enforceOrder( $enforceOrder ) },
        doubleClickable => sub { $_XTR->doubleClickable( $doubleClickable ) },
        relax           => sub { $_XTR->relax( $relax ) },
        stripVariables  => sub {
            croak "stripVariables() takes either a scalar or an arrayref, stopped"
                unless ( ! ref $stripVariables ||
                   ref $stripVariables eq "ARRAY" ); 
        },
    );
    
    my $fp = $actions{$name};
    &$fp if $fp;
}

=head2 addAttribute

    $foo->addAttribute( $foo );

Adds $foo to the attribute list. This method is normally called by the
L</Itexam::Attribute> constructor; however, on rare occasions it may
be called by the user to move attributes from one Examiner to another.

Current exercise data is cleared by this method.

=cut

sub addAttribute {
    my $self = shift;
    my $attr = shift;
    
    confess "Argument not an Itexam::Attribute, stopped"
        unless ref $attr && $attr->isa( "Tarp::Itexam::Attribute" );

    if ( $attr->{_exm} ) {
        return if $attr->{_exm} eq $self;
        $attr->{_exm}->takeAttribute( $attr );
    }
    
    my $uniqueName = $self->_approve( $attr->{name} );
    $self->{attributes}->{ $attr } = $uniqueName;
    $attr->{name} = $uniqueName;
    $attr->{_exm} = $self;
    undef $self->{listData};
}

=head2 attrNames

    @names = $exm->attrNames();

Returns the names of all attributes that are child to this Itexam.

=cut

sub attrNames {
    my $self = shift;
    return values %{$self->{attributes}};
}

=head2 attribute

    $attr = $foo->atttribute( "foo" );

Returns the attribute with the specified name, or C<undef> if an attribute with
the specified name does not exist.

=cut

sub attribute {
    my $self = shift;
    my $name = shift;
    while ( my ( $r, $n ) = each %{$self->{attributes}} ) {
        return $r if $name eq $n;
    }
    undef;
}

=head2 takeAttribute

    $foo->takeAttribute( $attr );

Detaches the attribute $attr from this Examiner. If the attribute does not
belong to this Examiner, C<undef> is returned.

Current exercise data is cleared by this method.

=cut

sub takeAttribute {
    my $self = shift;
    my $attr = shift;

    if ( defined $attr->{_exm} ) {
        undef $self->{listData};
        delete $self->{attributes}{$attr};
        undef $attr->{_exm};
    }
}

=head2 extractAttributes

    $foo->extractAttributes( $TEXfile );

Gets the value of all attributes from $TEXfile exercises.
Attributes are extracted by LaTeXtracting $TEXfile, then reading the
entire file into a line buffer and calling each attribute's preProcess() method.
The line buffer is then chopped up into "exercise buffers" containing the lines
belonging to each exercise in the input file, which are then passed on to each
attribute's value() method. Finally, postProcess() is called for each attribute.
The values can then be accessed through the L</listData> method.

If the C<value()> method changes the exercise buffer, this method checks that
the amount of lines in the exercise buffer hasn't been changed, and then copies
it back to the line buffer.  The modified line buffer can then be printed using
L</printLineBuffer>().

Attributes are tested in the order given by Tarp::Style::ITM->sort(). This
ensures a preorder traversal, where the value of an exercise will be tested
before parts and subparts. All exercise levels are tested with value(),
regardless of maxLevel(). If an attribute's inherit() flag is set, a parent
exercise's value will be used for parts and subparts.

The method returns true if the attributes were extracted successfully.
Otherwise, the return value is false and the errStr() method can be used to
retrieve an error description.  More serious errors, for example if $TEXfile
cannot be opened, result in an exception.

=cut

sub extractAttributes {
    my $self = shift;
    my $TEXfile = shift;
    
    confess "check usage" unless $TEXfile;
    return $self->_error( "File '$TEXfile' does not exist" )              unless -e $TEXfile;
    return $self->_error( "'$TEXfile' is a directory, not a file" )       unless -f _;
    return $self->_error( "Insufficient permissions to read '$TEXfile'" ) unless -r _;
    
    my ( $attributes, $_XTR )
        = @{$self}{ qw/ attributes _XTR / };
    
    return $self->_error( "No attributes defined" )
        unless keys %$attributes;

    $_XTR->read( $TEXfile )
        or return $self->_error( "Could not LaTeXtract '$TEXfile'\n" . $_XTR->errStr() );
    
    $_XTR->dumpItemData() if $Debugging;
    
    open( SLURP, $TEXfile ) or die "Could not open '$TEXfile' for reading: $!";
    my @lineBuffer = <SLURP>;
    close SLURP or die "Could not cose SLURP: $!";
    
    foreach ( @lineBuffer ) {
        s/\r\n/\n/;
    }
    
    # Use LaTeXtract data for all levels, so we can inherit attributes.
    my @xtData = map { $_XTR->lines( $_ ) } ( 0 .. $_XTR->seqCount - 1 );
    
    # For each attribute, call preProcess();
    foreach my $attribute ( keys %{$self->{attributes}} ) {
        $attribute->preProcess({
            TEXfile    => $TEXfile,
            listData     => \@xtData,
            lineBuffer => \@lineBuffer,
            eXtractor  => $_XTR, 
        });
    }
    
    my $listData = [{}];
    # For each exercise, get attribute values
    
    SEQ: for ( my $iseq = 0; $iseq < $_XTR->seqCount; $iseq++ ) {
        my $xtd = $xtData[ $iseq ];

        my @inorder = $_XTR->style()->sort( keys %$xtd );
        
        ITM: foreach my $ex ( @inorder ) {
            my $itemStack = $_XTR->style()->itemStack( $ex );
            my $rng = $xtd->{$ex};
            
            # Construct an exercise buffer using an array slice.
            my @exBuffer = @lineBuffer[ $rng->[0]-1 .. $rng->[1]-1 ];
            my $sizeBefore = @exBuffer;
            
            # Create a new record to save stuff to
            my $rec = $listData->[ $iseq ]{$ex} = {};

            foreach my $attribute ( keys %{$self->{attributes}} ) {
            my $attrName = $attributes->{$attribute};
                my $val;
                if ( $attribute->inherit() &&
                     @$itemStack > 1 ) {
                    # Inherit value from zero level exercise.
                    my $zeroL = $_XTR->style()->itemString( [ $itemStack->[0] ] );
                    my $zeroLrec = $listData->[ $iseq ]{$zeroL};
                    $val = $zeroLrec->{$attrName};                    
                } else {
                    # Get the value
                    $val = $attribute->value( {
                        TEXfile  => $TEXfile,
                        exSeq    => $iseq,
                        itemString => $ex,
                        itemStack  => $itemStack,
                        exLine   => $rng->[0],
                        exBuffer => \@exBuffer,
                        isLeaf   => $_XTR->isLeaf( $ex, $iseq ),
                        eXtractor => $_XTR,
                    } );
                }
                
                $rec->{$attrName} = $val;
            
                # Check the length of the buffer has not changed!
                my $sizeAfter = @exBuffer;
                return $self->_error( "Exercise buffer length (in lines) changed by attribute" . $attrName )
                    unless ( $sizeBefore == $sizeAfter );
            } # for each attribute

            # Copy the exercise buffer back to the file buffer
            @lineBuffer[ $rng->[0]-1 .. $rng->[1]-1 ] = @exBuffer;
            
        } # ITM loop
    } # SEQ loop

    # For each attribute, call postProcess();
    
    foreach my $attribute ( keys %{$self->{attributes}} ) {
        $attribute->postProcess({
            TEXfile    => $TEXfile,
            listData     => $listData,
            lineBuffer => \@lineBuffer,
            eXtractor  => $_XTR, 
        });
    }

    $self->_goStripVars( \@lineBuffer );
    
    @{$self}{qw/lineBuffer listData/} = ( \@lineBuffer, $listData );
    return 1;
}

=head2 data

    $foo = $bar->data( 1 );

Returns a hashref with exercise data found by L</extractAttributes>,
structured in the following format:

    {
        01a => {
            attr1 => 1,
            attr2 => 2,
               },
        01b => {
            attr1 => 3,
            attr2 => 4
            },
        ...
    };

where C<attr1> and C<attr2> are the names of the attributes that have been
specified by creating an C<Itexam::Attribute> subclass.  The exercise
numbers themselves are not sorted (when, for example, printing using the
Data::Dumper module or when iterating using C<each>).  The L</extractAttributes>
method must be called before this one; otherwise an empty hash will be returned.

=cut

sub data {
    my $self = shift;
    my $iseq = shift;
    
    my ( $_XTR, $listData, $maxLevel )
        = @{$self}{ qw/ _XTR listData maxLevel / };


    if ( defined $iseq && $iseq =~ /^\d+$/ ) {
        confess "Argument error: nonexistent sequence: $iseq, stopped"
            if ( $iseq < 0 || $iseq >= $self->seqCount() );
    } else {
        # determine $iseq automatically
        for my $i ( 0 .. $self->seqCount - 1 ) {
            if ( defined $iseq ) {
                undef $iseq;
                last;
            }
            if ( keys %{ $listData->[ $i ] } ) {
                $iseq = $i;
            }
        }
        return [ map { $self->data( $_ ) } 0 .. $self->seqCount - 1 ]
            unless defined $iseq;
    }

    # If all levels were being extracted, just return a copy of the
    # exercise data that was extracted.
    my %xd = %{$listData->[ $iseq ]};

    return \%xd
        if ( $maxLevel == Tarp::Itexam::ALL_LEVELS );

    # Otherwise, discard exercises above specified level...

    my %xd_trimmed = %xd;
    while ( my ( $ex ) = each %xd ) {
        my $level = @{ $_XTR->style()->itemStack( $ex ) } - 1;
        delete $xd_trimmed{$ex} if $level > $maxLevel;
    }

    # then discard all non-leaf exercises...
    my %xd_slaughtered = %xd_trimmed;
    while ( my ( $ex ) = each %xd_trimmed ) {
        my $parent = $ex;
        while ( $parent = $_XTR->style()->parentEx( $parent ) ) {
            delete $xd_slaughtered{$parent}
                if ( $parent && exists $xd_slaughtered{$parent} );
        }
    }

    return \%xd_slaughtered;
}

=head2 item

    $exm->item( "01aiv", 0 );

Returns an exercise record as a hashref for an exercise in a sequence.
Format is:

    {
        attr1 => 1,
        attr2 => 2,
        ...
    }

where attr1 and attr2 are the names of the attributes, and 1 and 2 their values.

=cut

sub item {
    confess "usage: OBJNAME->item( ex, seq ), stopped" unless @_ == 3;
    my $self = shift;
    my $ex   = shift;
    my $iseq = shift;
    
    if ( ! $self->exists( $ex, $iseq )) {
        carp "Exercise $ex does not exist in sequence $iseq";
        return;
    }
    
    return $self->{listData}[$iseq]{$ex};
}

=head2 lineCount

    $exm->lineCount();

Returns the amount of lines in the line buffer.

=cut

sub lineCount {
    my $self = shift;
    my $lc = @{$self->{lineBuffer}};
    return $lc;
}

=head2 preambleBuffer

Returns a line buffer arrayref containing preamble lines.  The preamble is defined as
the lines (if any) before the first C<beginTag> is encountered.  If the first
C<beginTag> is on line one, an empty arrayref is returned.  If there is no
C<beginTag> in the file, the result is undefined.

=cut

sub preambleBuffer {
    my $self = shift;
 
    # Preamble is from line 1 to the line before
    # the first "begin" tag.
    
    my $l0 = 1;
    my $l1 = undef;
    
    my ( $_XTR ) = @{$self}{qw/_XTR/};
    
    my $matches = $_XTR->matches();
    my @matchLines = sort { $a <=> $b } keys %$matches;
    
    my $beginFound = '';
    my $beginLine = undef;
    
    MATCH: foreach my $matchLine ( @matchLines ) {
        my $matchRec = $matches->{$matchLine};
        if ( $matchRec->{tag} eq "beginTag" ) {
            $beginFound = 1;
            $beginLine = $matchLine;
            last MATCH;
        }
    }
    
    return undef unless $beginFound;
    $l1 = $beginLine - 1; # So that we don't get the begin tag itself
    
    return [] unless $l1; # No preamble if begin is at line one
    return $self->lineBufferChunk( $l0, $l1 );
}

=head2 exBuffer

    $foo = $bar->exBuffer( "01aiv", 1 );

Returns an array reference with the lines corresponding to the specified exercise.
If the file has more than one numbering sequence, then the numbering sequence
to use should be supplied as a second argument (otherwise, if there is a single
numbering sequence this can be "0" or left blank).

=cut

sub exBuffer {
    my $self = shift;
    my $ex   = shift;
    my $iseq  = shift;
    
    my ( $_XTR )
        = @{$self}{ qw/ _XTR / };
    
    my $rng = $_XTR->item( $ex, $iseq );
    
    return $self->lineBufferChunk( $rng->[0], $rng->[1] );
}

=head2 exRangeBuffer

    $ex->exRangeBuffer( "01a", "01c", $seq );

Prints out the exercise buffers of the exercises given as first and second
arguments, plus everything in between.  The order doesn't matter; the above
example is equivalent to

    $ex->exRangeBuffer( "01a", "01c", $seq );

If either of the two exercises do not
exist in the numbering sequence, a warning is printed and C<undef> returned.
If one of the exercises is a parent or child of the other, an exception is
reaised.

If the same exercise is given, this call is equivalent to using L</exRange> on
that exercise.

=cut

sub exRangeBuffer {
    my $self = shift;
    my $firstEx = shift;
    my $lastEx = shift;
    my $seq = shift;
    
    my ( $_XTR, $lineBuffer )
        = @{$self}{ qw/ _XTR lineBuffer / };
    
    my $firstRange = $_XTR->item( $firstEx, $seq );
    my $lastRange  = $_XTR->item( $lastEx, $seq );
    
    return unless $firstRange && $lastRange;
    
    croak "Exercises $firstEx and $lastEx are parent-child, stopped"
        if ( $_XTR->style()->isParent( $firstEx, $lastEx ) ||
             $_XTR->style()->isChild( $firstEx, $lastEx ) );
    
    ( $firstRange, $lastRange ) = ( $lastRange, $firstRange )
        if ( $firstRange->[0] > $lastRange->[0] );

    return $self->lineBufferChunk( $firstRange->[0], $lastRange->[1] );
}

=head2 lineBufferChunk

    my $lines = $x->lineBufferChunk( 1, 42 );

Returns an arrayref with the specified lines of the line buffer.

=cut

sub lineBufferChunk {
    my $self = shift;
    my $fromLine = shift;
    my $toLine = shift;
    
    my $i0 = $fromLine-1;
    my $i1 = $toLine-1;
    
    my $lineBuffer = $self->{lineBuffer};

    my @chunk = @{$lineBuffer}[ $i0..$i1 ];
    
    return \@chunk;
}

=head2 printLineBuffer

    $x->printLineBuffer( $io );

Dumps the line buffer to the $io object, typically an IO handle or any other
object that offers a print method.

=cut

sub printLineBuffer {
    my $self = shift;
    my $outObj = shift;
    print $outObj @{$self->{lineBuffer}};
}

=head2 errStr

    $str = $exm->errStr();

Retrieves the error string

=cut

sub errStr { my $self = shift; $self->{_errStr}; }

=head1 LATEXTRACT WRAPPER METHODS

Wrapper methods are available for the following LaTeXtract methods:

=over

=item matches

=item dumpMatches

=item variables

=item seqCount

=item seqData

=item exercises

=item itemOnLine

=item exists

=item isSequential

=item isLeaf

=item find

=item style

=back

See L<Tarp::LaTeXtract> for more.

=cut

sub matches {
    my $self = shift;
    return $self->{_XTR}->matches( @_ );
}

sub dumpMatches {
    my $self = shift;
    return $self->{_XTR}->dumpMatches( @_ );
}

sub variables {
    my $self = shift;
    return $self->{_XTR}->variables( @_ );
}

sub seqCount {
    my $self = shift;
    return $self->{_XTR}->seqCount;
}

sub seqData {
    my $self = shift;
    return $self->{_XTR}->seqData( @_ );
}

sub exercises {
    my $self = shift;
    my $XTR = $self->{_XTR};
    $XTR->maxLevel( $self->{maxLevel} );
    my $exs = $XTR->exercises( @_ );
    $XTR->maxLevel( Tarp::LaTeXtract::ALL_LEVELS );
    return $exs;
}

sub itemOnLine {
    my $self = shift;
    my $XTR = $self->{_XTR};
    $XTR->maxLevel( $self->{maxLevel} );
    my $ex = $self->{_XTR}->itemOnLine( @_ );
    $XTR->maxLevel( Tarp::LaTeXtract::ALL_LEVELS );
    return $ex;
}

sub exists {
    my $self = shift;
    return $self->{_XTR}->exists( @_ );
}

sub isSequential {
    my $self = shift;
    return $self->{_XTR}->isSequential( @_ );
}

sub isLeaf {
    my $self = shift;
    return $self->{_XTR}->isLeaf( @_ );
}

sub find {
    my $class = shift;
    return Tarp::LaTeXtract->find( @_ );
}

sub style {
    my $self = shift;
    return $self->{_XTR}->style( @_ );
}

=head2 debug

    Tarp::Itexam->debug( $level )

Sets the debugging level.

=cut

sub debug {
    my $class = shift;
    if (ref $class)  { confess "Class method called as object method" }
    unless (@_ == 1) { confess "usage: CLASSNAME->debug(level)" }
    $Debugging = shift;
}

sub _goStripVars {
    my $self = shift;
    my $lineBuffer = shift;
    
    my %varsToStrip;
    
    my ( $stripVariables, $_XTR )
        = @{$self}{ qw/ stripVariables _XTR / };
    
    if ( ref $stripVariables eq "ARRAY" ) {
        @varsToStrip{ @$stripVariables } = @$stripVariables;
    } elsif ( $stripVariables ) {
        my @allVars = keys %{$_XTR->variables()};
        foreach my $v ( @allVars ) {
            $v =~ s/.*://;
            $varsToStrip{$v} = $v;
        }
    }

    if ( keys %varsToStrip ) {
        my %matches = %{$_XTR->matches()};
        MATCH: while ( my ( $ln, $matchRec) = each %matches ) {
            my ( $mTag, $mExp, $mVars, $mPos ) = @{$matchRec}{qw/tag exp vars pos/};
            next MATCH unless keys %$mVars;
            
            my $line = $lineBuffer->[$ln-1];
            my $newLine = '';
            
            my $prevPos = 0;
            
            # Variables in order of occurrence (left to right) in line
            my %varsByPos = reverse %$mPos;
            my @posInOrder = sort { $a <=> $b } keys %varsByPos;
            my @varsInOrder = @varsByPos{@posInOrder};

            # Replace variable contents with variable name
            VAR: foreach my $var ( @varsInOrder ) {
                next VAR unless $varsToStrip{ $var };
                my $pos = $mPos->{$var};
                my $sub = substr $line, $prevPos, $pos - $prevPos;
                $newLine .= $sub . "\$$var\$";
                $prevPos = $pos + length $mVars->{$var};
            }
            # Add remainder of line
            $newLine .= substr $line, $prevPos;
            
            $lineBuffer->[$ln-1] = $newLine;
        }
    }
}

sub _approve {
    my $self = shift;
    my $name = shift;
    
    my %names = reverse %{$self->{attributes}};
    my $uniqueName = $name;
    my $c = 2;
    while ( $names{ $uniqueName } ) {
        $uniqueName = $name . "_" . $c++;
    }
    return $uniqueName;

}

sub _error {
    my $self = shift;
    $self->{_errStr} = shift if @_;
    '';
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        my $v = $self->{$name} = shift;
        $self->_reload( $name );
        return $v;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;
