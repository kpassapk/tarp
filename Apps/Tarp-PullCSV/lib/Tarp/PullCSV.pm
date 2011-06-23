package Tarp::PullCSV;

use warnings;
use strict;
use Carp qw/croak confess/;

use Text::CSV;

use Tarp::Itexam;

=head1 NAME

Tarp::PullCSV - get exercise data as (csv) table

=head1 VERSION

Version 0.994

=cut

our $VERSION = '0.994';


=head1 SYNOPSIS

    use Tarp::PullCSV;

    my $foo = Tarp::PullCSV->new();

    # Add columns using this class or subclasses
    Tarp::PulCSV::Column->new( $csv );
    
    $foo->getColumnData();
    
    my $col = $foo->columns()->[0];
    my $colHeading = $col->heading();
    
    # column data as 2d array
    my $colData = $foo->columnData();
    
=head1 DESCRIPTION

This module gets attributes (pieces of information) from a TeX file containing
an exercise list.  Internally it uses Tarp::Itexam, but data is kept in a table
format instead of hashed by attribute name.

=cut

our $AUTOLOAD;

my %fields = (
    columns    => undef,
    columnData => undef,
);

sub PRINT_HEADINGS {1}

=head1 METHODS

=head2 new

    $csv->new();

Creates a new PullCSV object.

=cut

sub new {
    my $class = shift;
    my %opts = @_;

    my $self = {
        %fields,
        _EXM  => undef,
    };
    
    $self->{columns} = [];
    $self->{columnData} = [];
        
    my $EXM = Tarp::Itexam->new();
    $EXM->takeAttribute( $EXM->attribute( "line" ) );
    $EXM->maxLevel( 2 );

    $self->{_EXM} = $EXM;

    bless $self, $class;
    return $self;
}

=head2 addColumn

    $csv->addColumn( $col )
    $csv->addColumn( $col, $after );

Adds $col to the column list maintained by $csv. If $after is specified (an oref
to another column, inserts the new column after that one. Returns a true value
except if $after does not exist in $csv; in this case, $col is appended to the
column list.

=cut

sub addColumn {
    my $self  = shift;
    my $col   = shift;
    my $after = shift;

    if ( $col->{_csv} ) {
        return if $col->{_csv} eq $self;
        $col->{_csv}->takeColumn( $col );
    }
    $col->{_csv} = $self;
    
    if ( $after ) {
        my @cl;
        foreach ( @{$self->{columns}} ) {
            push @cl, $_;
            if ( $_ eq $after ) {
                push @cl, $col;
            }
        }
        if ( @cl > @{$self->{columns}} ) {
            # $col was inserted normally.
            $self->{columns} = \@cl;
            return 1;
        } else {
            # $after was not in the list.
            push @{$self->{columns}}, $col;
            return 0;
        }
    } else {
        push @{$self->{columns}}, $col;
        return 1;
    }
}

=head2 takeColumn

    $csv->takeColumn( $col );

Takes column $col (a Tarp::PullCSV::Column ref) from $csv.  Returns true unless $col does not
exist in $csv.

=cut

sub takeColumn ( $ ) {
    my $self = shift;
    my $col = shift;
    
    confess "check arguments"
        unless defined $col && ref $col && $col->isa( "Tarp::PullCSV::Column" );
    
    if ( $col->{_csv} == $self ) {
        # find column index
        
        my $ic = 0;
        foreach ( @{$self->{columns}} ) {
            last if $_ eq $col;
            $ic++;
        }
        # Remove from column list
        splice @{$self->{columns}}, $ic, 1;
        undef $col->{_csv};
        $self->{_EXM}->takeAttribute( $col->{_attr} );
    }
}

=head2 getColumnData

    $csv->getColumnData()

Extracts column data, which can be queried with colData() or output with write().
This method call's Itexam::extractAttributes(), which calls LaTeXtract's read(),
and issues an exception if there was a parse error.

=cut

sub getColumnData {
    my $self = shift;
    my $TEXfile = shift;
    
    my ( $columns, $columnData, $_EXM )
        = @{$self}{ qw/ columns columnData _EXM / };
    
    return unless @$columns;
    
    $_EXM->extractAttributes( $TEXfile )
        or die $_EXM->errStr() . "\n";

    my @colData = map { [] } @$columns;

    for ( my $seq = 0; $seq < $_EXM->seqCount; $seq++ ) {
        my $exs = $_EXM->exercises( $seq );
        my $exd = $_EXM->data( $seq );
        foreach my $ex ( @$exs ) {
            for ( my $ic = 0; $ic < @$columns; $ic++ ) {
                my $an = $columns->[ $ic ]->_attrName();
                my $val = $exd->{$ex}->{$an};
                push @{$colData[ $ic ]}, $val;
            }
        }
    }
    
    $self->{columnData} = \@colData;
}

=head2 columnData

    $d = $csv->columnData();

Returns a (ref to) an array of arrays corresponding to the data for all columns.

$d->[0] is a ref to an array with the values for column zero.  Note that this
means that $d->[0]->[1] is row 1, column 0, not row 0, column 1!

Column headings are not included.

=cut

=head2 write

    $csv->write( $io );
    $csv->write( $io, Tarp::PullCSV::PRINT_HEADINGS );

Writes column data to $io.  $io must be an IO::File or IO::Wrap object, not a
filehandle (apparently).

=over

=item PRINT_HEADINGS

If given as a second argument, headings will be printed by calling the heading()
method for every column.

=cut

=back

=cut

sub write {
    my $self = shift;
    my $io = shift;
    my $printHeading = shift;
    
    my ( $columns, $columnData, $_EXM )
        = @{$self}{ qw/ columns columnData _EXM/ };

    my $csv = Text::CSV->new;

    return unless @$columnData;
    my @c;
    
    my $printRow = sub {
        $csv->combine( @c )
            or croak "Text::CSV could not combine columns: " . $csv->error_diag;
        print $io $csv->string . "\n";
    };
    
    # Print headings
    if ( $printHeading ) {
        @c = map { $_->heading() } @$columns;
        &$printRow();
    }

    for ( my $i = 0; $i < @{$columnData->[0]}; $i++ ) {
        @c = map { $_->[$i] } @$columnData;
        &$printRow();
    }
}

=head2 style

    $csv->style( $sty );
    $sty = $csv->style();

Gets a reference to the style object.

=cut

sub style {
    my $self = shift;
    return $self->{_EXM}->style( @_ );
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

    perldoc Tarp::PullCSV


=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.


=cut

1; # End of Tarp::PullCSV
