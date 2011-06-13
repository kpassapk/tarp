package Tarp::LaTeXtract::Style;

=head1 NAME

Tarp::LaTeXtract::Style - LaTeXtract Style

The following tags are included by default when importing LaTeXtract::Style:

=over

=item B< C< beginTag > > (regular expression, 1+ values)

Moves down a level.

    Defualt: \\begin{enumerate}

=item B< C< endTag > > (regular expression, 1+ values)

Moves up a level; wraps up a line range.
    
    Default: \\end{enumerate}

=item sequenceRestart (regular expression, 0+ values, level -1)

Resets the zero-level numbering to zero.

    Default: (empty)

=back

The same entries and syntax are required when loading a .tas file.

=head2 DUMMY TAGS

=head2 Dummy Tags

Apart from the tags in the TAS file, the following dummy tags are defined:

=over

=item *

beginTag:  C< TECHARTS_DUMMY_BEGIN_TAG >
    
=item *

endTag:    C< TECHARTS_DUMMY_END_TAG >

=item *

itemTag: C< TECHARTS_DUMMY_ITEM_TAG-\($ITM$\) >

=back

These dummy tags are prepended to the value list of the above entries when
creating a new style or loading a style, and removed prior to saving.  If you
get one of these entres' values(), the dummy tag will show up as the first
element (also in qr() or interpolate(). )  To get the user values, i.e. without
the dummy tags, use userValues().  

=cut

use strict;
use Carp;

my $disabledTag    = 'TECHARTS_DISABLED_TAG';

my %fields = ();

# DUMMY tag assignment to each type of LaTeX tag
my %dummyTags = (
    beginTag    => 'TECHARTS_DUMMY_BEGIN_TAG',
    endTag      => 'TECHARTS_DUMMY_END_TAG',
    itemTag     => 'TECHARTS_DUMMY_ITEM_TAG-\($ITM$\)',
);

=head2 new

Do not use directly, but through Tarp::Style->new().

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    @{$self}{ keys %fields } = values %fields;
    return $self;
}

=head2 emptyFileContents

    (not user callable)

    # Tarp::LaTeXtract::Style
    
    beginTag = \\begin{enumerate}
    endTag   = \\end{enumerate}
    sequenceRestart =

=cut

sub emptyFileContents {
    my $class = ref $_[0] ? ref shift : shift;
    my $str = $class->SUPER::emptyFileContents();

    $str .= <<END_OF_TAS;

# Tarp::LaTeXtract::Style

beginTag = \\\\begin{enumerate}
endTag   = \\\\end{enumerate}
sequenceRestart =

END_OF_TAS

    return $str;
}

=head2 constraints

    (not user callable)

Returns constraints for beginTag, endTag, suquenceRestart

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %p = $self->SUPER::constraints( $tas );
    
    # For these entries, just having the dummy tag means they are still 'empty'.
    # Therefore, non-empty means two or more values.
    my $nonempty = [ sub { my $v = shift; @$v > 1 ? () : ( "empty list not allowed" ) } ];
    
    for ( qw/ sequenceRestart beginTag endTag/ ) {
        $p{$_} ||= Tarp::TAS::Spec->exists();
    }
    
    # sequenceRestart can be empty.
    $p{itemTag}  = Tarp::TAS::Spec->multi( $nonempty, $p{itemTag} );
    $p{beginTag} = Tarp::TAS::Spec->multi( $nonempty, $p{beginTag} );
    $p{endTag}   = Tarp::TAS::Spec->multi( $nonempty, $p{endTag} );

    return %p;    
}

=head2 postRead

    Adds dumy tags for itemTag, beginTag, endTag
    
=cut

sub postRead {
    my $self = shift;
    my $tas = shift;

    $self->SUPER::postRead( $tas );

    # Add dummy tags    
    while ( my ( $t, $d ) = each %dummyTags ) {
        my $e;
        if ( $e = $tas->{$t} ) {
            unshift @$e, $d
        }
#       my $isub = 0;
#       while ( $e = $tas->{"$t\_$isub\_"} ) {
        # Levels can be skipped!
        for my $isub ( 0 .. 3 ) {
            if ( $e = $tas->{"$t\_$isub\_"} ) {
                unshift @$e, $d;
                ++$isub;
            }
        }
    }
    
    $tas->{itemString}->[-1]->{EXCLUDE} = [ 1, {} ];
    $tas->{itemStack}->[-1]->{EXCLUDE} = [ 1, {} ];
    $tas->{itemSplit}->[-1]->{EXCLUDE} = [ 1, {} ];
    
}

=head2 dummyTag

    $t = $sty->dummyTag( "beginTag" );

Returns the dummy tag string for the specified tag.

=cut

sub dummyTag {
    my $self = shift;
    my $tag = shift;

    my $tag_type = $tag;
    $tag =~ s/_\d+_$//;
    if ( my $t = $dummyTags{ $tag } ) {
        return $t;
    }
    return '';
}

=head2 userValues

    @vals = $sty->userValues( $entry )

Returns the values for $entry without the dummy tags (if any).

=cut

sub userValues {
    my $self = shift;
    my $tag = shift;
    my @vals = @_;
    
    my $tag_type = $tag;
    $tag_type =~ s/_\d+_//;
    if ( my $d = $self->dummyTag( $tag_type ) ) {
        unshift @vals, $self->dummyTag( $tag_type ) if @vals;
        my @v = $self->SUPER::values( $tag, @vals );
        shift @v;
        return @v;
    } else {
        return $self->SUPER::values( $tag, @vals );
    }
}

=head2 userIndex

    $sty->userIndex( $tag, $idx );

Returns the user index for the corresponding tag and tas entry index. The user
index is one less than the tas index if the tag has a dummy, and the same
otherwise. 

=cut

sub userIndex {
    my $self  = shift;
    my $entry = shift;
    my $idx   = shift;
    
    confess "check usage"
        unless defined $entry && defined $idx && $idx =~ /\d+/;

    my $entry_type = $entry;
    my $user_index = $idx;
    $entry_type =~ s/_\d+_$//;
    if ( $dummyTags{ $entry_type } ) {
        --$user_index;
    }
    return $user_index;    
}

=head2 tasIndex

    $sty->tasIndex( $entry, $user_index );

Returns the tas index for the $user_index entry in $entry.  The tas index
is one more than the user index in tags that have a dummy value, and the same
otherwise. 

=cut

sub tasIndex {
    my $self  = shift;
    my $entry = shift;
    my $uidx   = shift;
    
    confess "check usage"
        unless defined $entry && defined $uidx && $uidx =~ /(?:-1)|\d+/;
    
    my $entry_type = $entry;
    my $index = $uidx;
    $entry_type =~ s/_\d+_$//;
    if ( $dummyTags{ $entry_type } ) {
        ++$index;
    }
    return $index;    
}

=head2 preWrite

Removes the dummy tags inserted above

=cut

sub preWrite {
    my $self = shift;
    my $tas = shift;
    
    $self->SUPER::preWrite( $tas );

    while ( my ( $t, $d ) = each %dummyTags ) {
        my $e = $tas->{$t};
            shift @$e if $e;
        my $isub = 0;
        while ( $e = $tas->{"$t\_$isub\_"} ) {
            shift @$e;
            ++$isub;
        }
    }
    

    $tas;
}

1;
