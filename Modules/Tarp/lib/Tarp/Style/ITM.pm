package Tarp::Style::ITM;

use strict;

=head1 NAME

Tarp::Style::ITM - $ITM$ style

=head1 SYNOPSIS

    use Tarp::Style::ITM;
    
    # e.g. for (number, letter, roman):
    Tarp::Style->import( qw/Tarp::Style::ITM Tarp::Style::ITM::NLR/ )
    
    my $style = Tarp::Style::ITM->new();
    
    # Get an item stack
    if ( $hlp->m( "itemString" => "01aiv" ) ) {
        $stack = $hlp->xformVars( $hlp->mVars(),
            "itemString" => "itemStack" )->{ITM};
        # stack contains [ 1, 1, 4 ]
    }

    # Turn it back into an item string
    
    print join '', @{ $hlp->xformVars( { ITM => $stack },
        "itemStack" => "itemString" )->{ITM} };
    # prints "01aiv";
    
    # Or shorthand...
    
    $stack = $hlp->itemStack( "01aiv" ); # contains [1, 1, 4]
    print $hlp->itemString( [1, 1, 4] ); # prints "01aiv"
    
    $gcl = $hlp->greatestCommonLevel( "01aix", "01" )   # $gcl == 1
    $gcl = $hlp->greatestCommonLevel( "01aiv", "01ai" ) # $gcl == 2
    
    $ex = $hlp->parentEx( "01aiv" ) # $ex is "01a"
    $yes = $hlp->isChild( "01aiv", "01a" ) # $yes is true
    
    $yes = $hlp->isInOrder( "01", "02" );
    $yes = $hlp->isInOrder( "01", "01a" );
    $yes = $hlp->isInOrder( "01ai", "01b" );
    
    @outOfOrder = ( qw/01a 03b 100 21aiv 20axv/ );
    
    @inOrder = $hlp->sort( @outOfOrder );
    # @inOrder is ( 01a 03b 20axv 21aiv 100 )

=head1 DESCRIPTION

This class provides some default entries that help with enumerated lists:

=over

=item itemString

An easy to read string representing an item.  Roughly sortable alphabetically.

=item itemStack

A list containing numeric counters for each list level.

=item itemSplit

A comma separated string with counters as they appear in the source file.

=back


=cut

use Carp;

=head2 new

    $sty = Tarp::Style->new();

=cut

sub new {
    my $class = shift;
    croak "Import using Tarp::Style->import() instead, stopped"
        unless $class eq "Tarp::Style";
    my $self = bless $class->SUPER::new(), $class;
    bless $self, $class;

    return $self;
}

=head2 emptyFileContents

Appends the following lines to the superclass's empty file contents:

    itemTag_0_ = <illegal>-$ITM$
    itemTag_1_ = $ITM$
    itemTag_2_ = $ITM$
    itemTag_3_ = $ITM$

The $ITM$ definition is in preRead().

=cut

sub emptyFileContents {
    my $self = shift;
    my $str = $self->SUPER::emptyFileContents();
    # Cannot have items at level zero
    $str .= "itemTag[0] = <illegal>-\$ITM\$\n";
    for ( my $i = 1; $i < 4; $i++ ) {
        $str .= "itemTag[$i] = \$ITM\$\n";
    }
    return $str;
}

=head2 constraints

    $sty->constraints();

Sets the following constraints:

=over

=item *

itemTag

Regular expressions, 1+ values, require $ITM$ variable

=back

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %p = $self->SUPER::constraints( $tas );

    my $itemTags = Tarp::TAS::Spec->simple( allowEmpty => 0, requireVars => [ qw/ITM/ ] );

    # The existing $p{itemTag} checks for RX correctness.  We keep it.
    $p{itemTag} = Tarp::TAS::Spec->multi( $p{itemTag}, $itemTags );
    
    return %p;
}

=head2 preRead

    (not user callable)

These lines re always added, whether or not reading from a file.

=cut

sub preRead {
    my $self = shift;
    my $contents = shift;
    
my $str = <<END_OF_TAS;
# Tarp::Style::ITM

itemString = \\
    \\b\$ITM\$\$ITM\$\$ITM\$\\b \\
    \\b\$ITM\$\$ITM\$\\b \\
    \\b\$ITM\$\\b

    itemString::ITM = a b c # temporary

itemStack = \$ITM\$,\$ITM\$,\$ITM\$
    itemStack::ITM = \\d+

itemSplit = \$ITM\$,\$ITM\$,\$ITM\$
    itemSplit::ITM = a b c

itemTag[0]::ITM = 0

END_OF_TAS

    for ( my $i = 1; $i < 4; $i++ ) {
        $str .= "itemTag[$i]::ITM = temp\n";
        $str .= "itemTag[$i]::ITM::WORD = 1\n\n"
    }
    return $contents . $str;
}

=head2 preWrite

Removes itemString, itemStack, itemTag[0]::ITM thru itemTag[4]::ITM

=cut

sub preWrite {
    my $self = shift;
    my $tas = shift;

    delete $tas->{itemString};
    delete $tas->{itemStack};
    delete $tas->{itemSplit};
    
    for ( my $i = 0; $i < 4; $i++ ) {
        delete $tas->{"itemTag_$i\_"}->[-1]->{ITM};
    }
    
    1;
}

=head2 itemString

    $str = $h->itemString( [1, 1, 4] ); # str is now "01aiv".

Turns an exercise stack into an exercise string.

=cut

sub itemString {
    my $self = shift;
    my $itemStack = shift;
    
    confess "check usage" unless defined $itemStack;
    
    my $xf = $self->xformVars( { ITM => $itemStack }, "itemStack", "itemString" )->{ITM};
    join( '', @$xf );
}

=head2 itemStack

    $es = $h->itemStack( "01aiv" );
    # $es == [ 1, 1, 4 ];

Turns an exercise string into an exercise stack.  If the current
string cannot be parsed, returns C<undef>.  If an empty string
is given, returns a ref to an empty array.

=cut

sub itemStack {
    my $self = shift;
    my $itemString = shift;

    confess "check usage" unless defined $itemString;
    
    my @qrs = $self->qr( "itemString" );
    foreach ( @qrs ) {
        if ( $itemString =~ $_ ) {
            return $self->xformVars( \%-, "itemString", "itemStack" )->{ITM};
        }
    }
    undef;
}

=head2 greatestCommonLevel

    $i = $h->greatestCommonLevel( "01aiv", "01ai" ); # i == 1
    $i = $h->greatestCommonLevel( "01", "02" );      # i == -1

Returns the greatest common level of two exercise strings. If the exercises have
nothing in common, returns -1.  If either of the two exercises cannot be parsed,
returns C<undef>.

=cut

sub greatestCommonLevel {
    my $self = shift;
    my $str1 = shift;
    my $str2 = shift;
    
    confess "This function expects two arguments" unless $str1 && $str2;
    
    my @es1 = @{$self->itemStack( $str1 )};
    my @es2 = @{$self->itemStack( $str2 )};
    
    return undef unless ( @es1 && @es2 );
    
    # Get the one with the least elements
    my $smallest = @es1 < @es2 ? @es1 : @es2;
    
    my $i = 0;
    for ( ; $i < $smallest; $i++ ) {
        last unless ( $es1[$i] == $es2[$i] )
    }
    return $i-1;
}

=head2 sort

    $sorted = $h->sort( qw/01a 03 01b 01ai/ );

Sorts a list of exercises in logical order (note that this is not necessarily
the order that they actually appear in a file due to columns).  

=cut

sub sort {
    my $self = shift;
    my @unsorted = @_;
        
    my %sortable;
    # Sortable stringified exercise has three places per exercise level, all
    # numeric, so 01aiv becomes 001001004.
    
    foreach my $uns ( @unsorted ) {
        my $es = $self->itemStack( $uns );
        my $ss = '';
        for ( my $i = 0; $i < 3; $i++ ) {
            my $n = $es->[$i] || 0;
            $ss .= sprintf( "%0*d", 3, $n );
        }
        $sortable{$ss} = $uns;
    }

    my @sortedKeys = sort { $a <=> $b } keys %sortable;
    my @sorted = @sortable{@sortedKeys};
    
    return @sorted;
}

=head2 isInOrder

    $yes = $fmt->isInOrder( "01a", "01b" );
    $no  = $fmt->isInOrder( "01", "02a" );

Returns true if the two exercises given as arguments are in order (note that
this does not mean that they are actually I<sequential>, which is determined by
LaTeXtract).  The following exercises are in order:

=over

=item *

Next exercise at the same level.

    example: 01a, 01b

=item *

Next exercise one or more levels up from the first.

    examples: (01aiv, 01b) or (01aiv, 02)

=item *

Next exercise down one level from the first.

    examples: (01a, 01ai) or (01, 01a)

=back

=cut

sub isInOrder {
    my $self = shift;
    my $lastEx = shift;
    my $ex = shift;
    
    # Possible are next, up one or more levels and down one level.
    my $lastStack   = $self->itemStack( $lastEx );
    my %possible = ();
    
    my @nextSameLevel = @$lastStack;
    $nextSameLevel[-1]++;
    $possible{$self->itemString( \@nextSameLevel )} = 1;
    
    my @upOneLevel = @$lastStack;

    while ( @upOneLevel ) {
        pop @upOneLevel; # Could be empty list
        if ( @upOneLevel ) {
            $upOneLevel[-1]++;
            $possible{ $self->itemString( \@upOneLevel ) } = 1;
        }
    }

    my @downOneLevel = @$lastStack < 3 ? @$lastStack : ();
    push @downOneLevel, 1 if @downOneLevel; # Could be empty list
    
    $possible{ $self->itemString( \@downOneLevel ) } = 1;
    return $possible{$ex} || '';
}

=head2 parentEx

    $ex = $h->parentEx( "01aiv" ); # ex is now '01a'

Returns the parent exercise.  If a zero-level exercise is given,
an empty string is returned.  If an invalid exercise is given,
C<undef> is returned.  If an empty string is given, C<undef> is
returned.

=cut

sub parentEx {
    my $self = shift;
    my $str = shift;
    return undef if $str eq '';
    my $es = $self->itemStack( $str );
    return unless defined $es;
    pop @$es;
    return $self->itemString( $es );
}

=head2 isChild

    $true = $h->isChild( "01aiv", "01a" );

Returns C<1> if the exercise given as a first argument is child
of the exercise given as a second argument, and the empty string
otherwise.

=cut

sub isChild {
    my $self = shift;
    my $child = shift;
    my $parent = shift;
    
    confess "check usage" unless defined $child && defined $parent;
    
    return $self->_error( "$child is not an itemString" )
        unless $self->m( "itemString" => $child );

    return $self->_error( "$parent is not an itemString" )
        unless $self->m( "itemString" => $parent );
    
    my $isChild = '';
    my $p = $child;
    while ( $p = $self->parentEx( $p ) ) {
        $isChild = 1 if $p eq $parent;
    }
    return $isChild;
}

=head2 isParent

    $yes = $itm->isParent( "01a", "01aiv" );

Returns C<1> if the exercise given as a first argument is parent
of the exercise given as a second argument, and the empty string
otherwise.

=cut

sub isParent {
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    
    return $self->isChild( $child, $parent );
}

1;
