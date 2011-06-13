package Tarp::GenSkel::Style;
use strict;

=head1 NAME

Tarp::GenSkel::Style - style for Tarp::GenSkel

=cut

use Carp;

my @nonPrintables = (
    qr/(?:^|[^\\])\\[a-z]/ # Escaped character
);
my @npTags = ( qw/beginTag endTag itemTag/ );

=head1 METHODS

=head2 new

    Tarp::Style->import( "Tarp::GenSkel::Style" );
    $sty = Tarp::Style->new();

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    my @friends = ( qw/Tarp::LaTeXtract::Style Tarp::Style::ITM/ );
    for ( @friends ) {
        croak "Tarp::GenSkel::Style must be imported along with '$_', stopped"
            unless $class->isa( $_ );
    }
    return $self;
}

=head2 constraints

    %c = $sty->constraints( $tas );

Returns constraints for itemTag_0_, itemTag_1_, itemTag_2_, beginTag, and endTag that
prohibits the first value from having non printable characters.

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %p = $self->SUPER::constraints( $tas );
    
    my $npTest = [ sub {
        my $v = shift;
        for my $c ( @nonPrintables ) {
            return ( "Value '$v->[1]' contains non printable characters" )
                if $v->[1] =~ $c;
        }
        ();
    }];
    
    for ( @npTags ) {
        $p{$_} = Tarp::TAS::Spec->multi( $p{$_}, $npTest );
    }
    %p;
}

1;
