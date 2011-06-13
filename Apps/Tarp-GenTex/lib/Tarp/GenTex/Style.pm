package Tarp::GenTex::Style;

=head1 NAME

Tarp::GenTex::Style - Style for Tarp::GenTex

=head1 SYNOPSIS

    Tarp::Style->import( "Tarp::GenTex::Style" );
    
    $style = Tarp::Style->new();
    my $TEXfile = "7et0102.tex";

    # If we want to turn "01" and "02" to "1" and "2"...
    $style->impXforms( 1 );
    $style->m( "filename", $TEXfile )
        or die "Could not match filename '$TEXfile', stopped";

    my $vars = $style->xformVars( $style->mVars(), "filename" => "texVars" );

=head1 DESCRIPTION

This style uses two entries, "filename" and "texVars".

The first is matched against the pickup list filename; any variables are
remembered and translated into "texVars" contex, determining which of the
"filename" variables appear in the tex file itself.  If texVars is empty, no
variables get through.

=cut

use strict;

=head2 new

    Tarp::Style->import( "Tarp::GenTex::Style" );
    my $sty = Tarp::Style->new();

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    return $self;
}

=head2 emptyFileContents

    filename = .*
    texVars  = 

=cut

sub emptyFileContents {
    my $self = shift;
    return $self->SUPER::emptyFileContents() . <<END_OF_TAS;

# Tarp::GenTex::Style

filename = .*
texVars  = 

END_OF_TAS
}

=head2 constraints

    (not user callable)

If "filename" is defined, requires "texVars" as well.

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    
    my %p = $self->SUPER::constraints( $tas );
    if ( $p{filename} ) {
        $p{texVars} ||= Tarp::TAS::Spec->exists();
    }
    %p;
}

1;
