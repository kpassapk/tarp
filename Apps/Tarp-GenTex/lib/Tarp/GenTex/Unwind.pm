package Tarp::GenTex::Unwind;

=head1 NAME

Tarp::GenTex::Unwind - unwind exercises as they would appear in a file

=head1 SYNOPSIS

    use Tarp::GenTex::Unwind;
    
    $uw = Tarp::GenTex::Unwind->new();
    
    @l = $uw->unwind( qw/01a 01b 01c 02 03a 03b/ );
    
    print "@l";
    # Will print "1 a b c 2 3 a b"    

=head1 DESCRIPTION

This class "unwinds" a list of exercises into the order they would appear in
a TeX list. For example, the exercises 01a and 01b would be written in a TeX
list like this:

    \begin{enumerate}
    \item[1.]
    \begin{enumerate}
    \item[(a)]
    \item[(b)]
    \end{enumerate}
    \end{enumerate}

Only looking at the numbers and letters in the C<item> tags, we see that these
are in the "unwound" order C<1>, C<a>, C<b>.

=cut

use strict;
use warnings;
use Carp;
use Tarp::Style;

our $AUTOLOAD;

my %fields = (
    style => undef,
);

=head2 new

    $uw = Tarp::UnwindItems->new();

Creates a new unwinder, importing by default Tarp::Style::ITM and
Tarp::Style::ITM::NLR.

=cut

sub new {
    my $class = shift;
    
    Tarp::Style->import( map { "Tarp::Style::$_" } qw/ITM ITM::NLR/ );
    
    my $self = bless {
        %fields,
    }, $class;

    $self->{style} = Tarp::Style->new();
    
    return $self;
}

=head2 unwind

    @list = $uw->unwind( qw/01a 01b 02a 02b ... / );

Unwinds the given list to file order

=cut

sub unwind {
    my $self = shift;
    my @exs = @_;

    my $sty = $self->style();
    
    my @unwound = ();
    my $lastEx = '';
    
    foreach my $ex ( @exs ) {
        $sty->m( "itemString", $ex )
            or croak "'$ex' is not an item string, stopped";
        
        my @itemSplit = @{ $sty->mVars()->{ITM} };

        my @texSplit;
        for ( 1 .. @itemSplit ) {
            push @texSplit, $sty->xformVars( $sty->mVars(), "itemString" => "itemTag_$_\_" )->{ITM}->[0];
        }

        my $gcl = $lastEx ?
            $sty->greatestCommonLevel( $ex, $lastEx ) : -1;
        
        # Return all the levels above gcl.        
        for ( my $i = $gcl + 1; $i < @texSplit; $i++ ) {
            push( @unwound, $texSplit[$i] );
        }
        
        $lastEx = $ex;
    }
    @unwound;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/ ) {
        croak "Can't access `$name' field in class $type, stopped";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;