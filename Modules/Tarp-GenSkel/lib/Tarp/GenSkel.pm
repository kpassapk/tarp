package Tarp::GenSkel;

=head1 NAME

Tarp::GenSkel - Generate skeleton file from chunk list

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    $gs = Tarp::GenSkel->new();

    $gs->addChunk( "01a, "01b" );
    $gs->addChunk( "02" );
    
    my $io = IO::File->new;
    $io->open( ... );
    
    $gs->printSkel( $io )

=head1 DESCRIPTION

GenSkel prints a skeleton of a TeX exercise list using tags found in a
TAS file.

A skeleton for the input above would typically look like the following:

    \begin{enumerate}
    \item[$ITM$.]
    \begin{enumerate}
    \item[($ITM$)]
    INSERT CHUNK HERE FOR 01a to 1b
    \end{enumerate}
    \item[($ITM$)]
    INSERT CHUNK HERE FOR 02
    \end{enumerate}

The actual tags C<\begin{enumerate}>, C<\item[...]> and so on are taken
from the first entry of the following tags in the C<TAS> file:

=over

=item * beginTag

=item * endTag

=item * itemTag_0_

=item * itemTag_1_

=item * itemTag_2_

=back

Since these entries are in the form of regular expressions, they are
modified slightly in order to make them "printable", according to the
following rules:

=over

=item *

Whitespace (\s) is replaced with an actual space.

=item *

All non-doubled-up backslashes are removed;
doubled-up backslashes are replaced with a single backslash.

=item *

Anchoring patterns removed: word boundaries (C<\b>).

=back

=cut

use strict;
use warnings;
use Carp;

use Tarp::LaTeXtract;

my %fields = ();

=head1 METHODS

=head2 new

    $gs = Tarp::GenSkel->new();

=cut

sub new {
    my $class = shift;

    return if @_;
    
    Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
    Tarp::Style->import( "Tarp::LaTeXtract::Style" );
    Tarp::Style->import( "Tarp::GenSkel::Style" );
    
    my $self = {
        _permitted => \%fields,
        %fields,
        # private:
        chunks => [],
        tags => {},
        _style => Tarp::Style->new(),
    };
    
    bless $self, $class;
    return $self;
}

sub _tags {
    my $self = shift;
    my ( $_style ) = @{$self}{qw/_style/};
    
    my @allTags;
    push( @allTags, ( $_style->values( "itemTag_1_" ))[1] );
    push( @allTags, ( $_style->values( "itemTag_2_"))[1] );
    push( @allTags, ( $_style->values( "itemTag_3_"))[1] );
    
    push( @allTags, ( $_style->values( "beginTag" ))[1] );
    push( @allTags, ( $_style->values( "endTag" ))[1] );
    
    # Turn regexp into a printable string:
    
    for ( my $i = 0; $i < @allTags; $i++ ) {
        # Remove all backslashes that are not followed
        # by another backslash
        $allTags[$i] =~ s/\\([^\\])/$1/g;
    }
    
    my @itemTags = @allTags[0..2];
    my $beginTag = $allTags[3];
    my $endTag = $allTags[4];
    
    my %tags;
    @tags{qw/beginTag endTag itemTags/} =
        ( $beginTag, $endTag, \@itemTags );

    return \%tags;    
}

=head2 addChunk

    $gen->addChunk( "01a" );
    $gen->addChunk( "02a", "02c" );

Adds a chunk starting at the exercise given as a first argument and ending at
the exercise given as a second argument. If the second argument is not given,
then the chunk is assumed to contain only a single exercise.

Note that only the level of the exercises is significant, and not their actual
contents (the exercise "string").  The latter is only printed out after
c<INSERT CHUNK HERE>; the actual structure of the skeleton file is determined
only by the changes in exercise level set by successive addChunk calls. Therefore
the following yields a skeleton file with the same structure as the example above:

    $gen->addChunk( "01b" );
    $gen->addChunk( "01a", "01c" );

The only difference will be what is printed after C<INSERT CHUNK HERE>.

=cut

sub addChunk {
    my $self = shift;
    my $first = shift;
    my $last = shift || $first;
    
    push( @{$self->{chunks}}, [ $first, $last ]);
}

=head2 printSkel

    $sk->printSkel( $io );

Prints skeleton to $io.  This must be an C<IO::File> object, a filehandle
wrapped using C<IO::Wrap>, or any other object with a "print" function.

=cut

sub printSkel {
    my $self = shift;
    my $io = shift;
    
    my $_style = $self->{_style};
    
    my $tags = $self->_tags();
    
    sub _clean { $_ = shift; s/^"//; s/"$//; $_ }
    # Start at level -1
    # Get level of first exercise
        
    my $ex_end_0 = '';
    my $l_end_0  = -1;
    my $l_end    = -1;
    
    print $io "INSERT PREAMBLE HERE\n";
    
    foreach my $chunk ( @{$self->{chunks}}) {
        my $l_start = @{$_style->itemStack( $chunk->[0] )} - 1;
        $l_end =      @{$_style->itemStack( $chunk->[1] )} - 1;

        my $l_gc = $ex_end_0 ?
            $_style->greatestCommonLevel( $ex_end_0, $chunk->[0] )
            :
            -1;

        $self->_changeLevel( $l_end_0, $l_gc + 1, $io, $tags );
        print $io _clean( $tags->{itemTags}[ $l_gc + 1 ]  ) . "\n";
        if ( $self->_changeLevel( $l_gc + 1, $l_start, $io, $tags ) ) {
            print $io _clean( $tags->{itemTags}[$l_start] ) . "\n";
        }
        my $display = ( $chunk->[0] eq $chunk->[1] ) ?
            $chunk->[0]
            :
            "$chunk->[0] to $chunk->[1]";
        print $io "INSERT CHUNK HERE FOR $display\n";

        $ex_end_0 = $chunk->[1];        
        $l_end_0 = $l_end;
    }
    
    $self->_changeLevel( $l_end, -1, $io, $tags );
}

=head2 style

=cut

sub style {
    my $self = shift;
    if ( @_ ) {
        croak "Style must be 'Tarp::Style' ref" unless ref $_[0] eq "Tarp::Style";
        return $self->{_style} = shift;
    } else {
        return $self->{_style};
    }
}

# changeLevel: The guts of the module.  Changes level from the first arg to the
# second arg by printing the necessary "begin", "end", and "item" tags to $io.
# returns true if level was changed, and false otherwise.

sub _changeLevel {
    my $self = shift;
    my $l_from = shift;
    my $l_to = shift;
    my $io = shift;
    my $tags = shift;
    
    die "Cannot change from level $l_from (valid range is -1..2), stopped"
        if ( $l_from < -1 || $l_from > 2 );
    
    die "Cannot change to level $l_to (valid range is -1..2), stopped"
        if ( $l_to < -1 || $l_to > 2 );
    
    if ( $l_from < $l_to ) {
        # Going "down" a level, e.g. "01a" (level 1) from file level (level -1).
        # Here it would print begin, item, begin.  The final item is not printed.
        for ( my $i = $l_from; $i < $l_to; $i++ ) {
            print $io $tags->{beginTag} . "\n";
            print $io $tags->{itemTags}[$i+1] . "\n"
                unless ( $i == $l_to - 1 );
        }
    } elsif ( $l_from > $l_to ) {
        # Going "up" a level, e.g. 01a (level 1) to file level (level -1).
        # Here it would print end, end.
        for ( my $i = $l_from; $i > $l_to; $i-- ) {
            print $io $tags->{endTag} . "\n";
        }
    }
    return $l_from != $l_to;
}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::GenSkel

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1;