package Tarp::GenPK::Style;
use strict;

=head1 NAME

Tarp::GenPK::Style - style for Tarp::GenPK

=head2 SYNOPSIS

    use Tarp::Style;
    
    Tarp::Style->import( "Tarp::GenPK::Style" );
    
    my $sty = Tarp::Style->new();

    $sty->values( $sty->csvString() );
    $sty->values( $sty->filename() );

=head1 METHODS

This style exposes the methods "csvString" and "filename".

=cut

use Carp;

my %fields = (
    csvString => "csv_string",
    filename  => "filename",
);

# CSV column types (not order!)
my %colTypes = (
    EX          => "New edition column",
    PKEX        => "Pickup column(s)",
    NEW         => "NEW column",
    MASTER      => "MasterID column",
);

=head2 emptyFileContents

Adds the following lines:

    csv_string = $chapter$.$section$.$itemString$
        csv_string::chapter = .*
        csv_string::section = .*
        # csv_string::itemString is set automagically
        
        csv_string::EXACT = 1

    filename = $book$$chapter$$section$
        $filename::book = .*
        $filename::chapter = .*
        $filename::section = .*

    heading_EX = $book$\s+problem
        heading_EX::EXACT = 1
        heading_EX::CSENS = 0
        heading_EX::book = .+

    heading_PKEX = $book$\s+pickup
        heading_PKEX::EXACT = 1
        heading_PKEX::CSENS = 0
        heading_PKEX::book = .+

    heading_NEW = NEW
        heading_NEW::EXACT = 1

    heading_MASTER = MasterID
        heading_MASTER::EXACT = 1

where csv_string and filename are the values set using the csvString() and
filename() methods, respectively.

=cut

sub emptyFileContents {
    my $self = shift;
    my $c = $self->SUPER::emptyFileContents();
    my ( $csvString, $filename ) = @{$self}{ qw/csvString filename/ };
    my $s = <<END_OF_TAS;
# ----- Tarp::GenPK::Style ------
$csvString = \$chapter\$\\.\$section\$\\.\$itemString\$
    $csvString\::chapter = .*
    $csvString\::section = .*
    $csvString\::EXACT = 1
$filename  = \$book\$\$chapter\$\$section\$
    $filename\::book = .*
    $filename\::chapter = .*
    $filename\::section = .*
heading_EX = \$book\$\\s+problem
    heading_EX::EXACT = 1
    heading_EX::CSENS = 0
    heading_EX::book = .+
heading_PKEX = \$book\$\\s+pickup
    heading_PKEX::EXACT = 1
    heading_PKEX::CSENS = 0
    heading_PKEX::book = .+
heading_NEW = NEW
    heading_NEW::EXACT = 1
heading_MASTER = MasterID
    heading_MASTER::EXACT = 1

END_OF_TAS
    return $c . $s;
}

=head2 new

    Tarp::Style->new();

Creates a new style with Tarp::GenPK::Style

=cut

sub new {
    my $class = shift;
    
    confess "'Tarp::GenPK::Style' requires import of 'Tarp::Style::ITM', stopped"
        unless $class->isa( "Tarp::Style::ITM" );
    
    my $self = bless $class->SUPER::new(), $class;
    @{$self}{keys %fields} = values %fields;
    $self->{_colTypes} = \%colTypes;
    return $self;
}

=head2 constraints

Adds the following constraints:

    $filename       must have $book$, $chapter$, $section$
    $csvString      must have $chapter, $section$, $itemString$
    heading_EX      must have $book$
    heading_PKEX    must have $book$
    heading_NEW     must exist
    heading_MASTER  must exist

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %p = $self->SUPER::constraints( $tas );

    my $csvString = $self->csvString();
    my $filename = $self->filename();
    
    # We've got to do this in case these don't exist
    
    $p{ $csvString } ||= Tarp::TAS::Spec->exists();
    $p{ $filename  } ||= Tarp::TAS::Spec->exists();

    foreach ( keys %colTypes ) {
        $p{ "heading_" . $_ } ||= Tarp::TAS::Spec->exists();
    }

    my $vcCheck = sub {
        my $vs = shift;
        my $nv = shift;
        my $tas = shift;
        my @errs = ();
        return "Empty list not allowed" unless @$vs;
        foreach ( @$vs ) {
            my @nf = /\(?<\w+>/g;
            my $nf = 0 + @nf;
            push @errs, "'$_' must have $nv variables (has $nf)" if $nf != $nv;
        }
        return @errs;
    };
    
    # Must have three variables...
    $p{ $csvString } = Tarp::TAS::Spec->multi(
        $p{$csvString},
        [ $vcCheck, 3, $tas ] 
    );
    
    # Including "itemString"
    $p{ $csvString } = Tarp::TAS::Spec->multi(
        $p{$csvString},
        Tarp::TAS::Spec->simple(
            requireVars => [ "itemString" ],
            allowEmpty  => '',
        )
        
    );

    $p{ $filename } = Tarp::TAS::Spec->multi(
        $p{$filename}, 
        Tarp::TAS::Spec->simple(
            requireVars => [ qw/book chapter section/ ],
            allowEmpty => '',
            allowMultiple => ''
        )
    );
    
    my $hs = Tarp::TAS::Spec->simple(
        requireVars => [ qw/book/ ],
        allowEmpty  => '',
        allowMultiple => ''
    );
    
    $p{heading_PKEX} = Tarp::TAS::Spec->multi(
        $p{heading_PKEX},
        $hs
    );    

    $p{heading_EX} = Tarp::TAS::Spec->multi(
        $p{heading_EX},
        $hs
    );

    return %p;
}

=head2 preRead

Adds csv_string::itemString definition (null value for now)

=cut

sub preRead {
    my $self = shift;
    my $contents = $self->SUPER::preRead( shift );
    
    my $csvString = $self->csvString();
        
my $str = <<END_OF_TAS;

$csvString\::itemString = temp

END_OF_TAS

    return $contents . $str;
}

=head2 postRead

Sets the csv_string entry to the same value as the style's itemString entry,
defined by Tarp::Style::ITM

=cut

sub postRead {
    my $self = shift;
    my $tas = shift;
    
    $self->SUPER::postRead( $tas );

    # set csv_string::itemString to regexps that match an item.
    my $csvString = $self->csvString();
    my $inl = $tas->interpolate( "itemString" );
    my $eqv = "(?:" . join( ")|(?:", @$inl ) . ")";

    $tas->{$csvString}->[-1]->{itemString}->[0] = $eqv;

    1;
}

=head2 preWrite

Removes the csv_string::itemString entry.

=cut

sub preWrite {
    my $self = shift;
    my $tas  = shift;
    
    $self->SUPER::preWrite( $tas );

    my $csvString = $self->csvString();
    delete $tas->{$csvString}->[-1]->{itemString};
}

=head2 colTypes

    $sty->colTypes();

Returns a hash ref with a column names (ITM,PKEX,NEW,MASTER) and descriptions
(values)

=cut

sub colTypes {
    my $self = shift;
    return $self->{_colTypes};
}

1;
