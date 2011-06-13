package Tarp::GenPK;

use warnings;
use strict;

=head1 NAME

Tarp::GenPK - generate .pklists from correlation .csv

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    use Tarp::GenPK;

    $gpk = Tarp::GenPK->new();
    
    $gpk->readCorrelation( "chapter.csv" );

    $book = $gpk->book();
    
    $gpk->createPKlists();
    
=head1 DESCRIPTION

This module reads a correlation C<CSV> file and produces a series of
pickup list (C<.pklist>) files. A correlation .csv file must have at least the
following columns, in no particular order.  Columns are identified by matching
them against a style entry called "heading_(col)" where (col) is C< ITM >, C< PKEX >,
c< NEW > or C< MASTER >.  See Tarp::GenPK::Style for the default for each of
these entries.

=over

=item * ITM

(exactly one)

B<Exercise (new edition)>: Contains fully qualified exercises in the current
edition. Example: C< 01.01.01a >. The C< heading_EX > entry must have a C< $book$ >
capture buffer used for the name of the new book. Records in this column are
matched against the C< csv_string > entry (or whatever the style's csvString()
method contains) to extract the chapter, section and exercise. 

=item * PKEX

(at least one)

B<Pickup(s)>: Contain fully qualified pickup exercises. Example: C<01.01.01a>.
The C<heading_PKEX> entry must have a $book$ capture buffer, which is used for
the name of the new book. Multiple pickup columns may exist. Records in this
column are matched against the C<csv_string> entry (or whatever the style's
csvString() contains) to extract the chapter, section and exercise.

=item * NEW

(exactly one)

B<NEW column>: Contains a flag that specifies a problem as being "new".
Eaxmple: C<new>. Only a single C<NEW> column may exist.

=item * MASTER

(exactly one)

B<MasterID column>:  Contains a C<MasterID> number.  Example: 12345.  Only
a single MasterID column may exist.

=back

A set of pickup lists are extracted from a single correlation file, one list
per section.  Pickup lists are placed in the current directory and are given
have the following columns:

=over

=item * ITM

New edition exercise, e.g. C< 01a >.  From ITM 

=item * PKFILE

Pickup file ID

=item * PKEX

Pickup exercise

=item * MASTER

MasterID

=back

=cut

use Carp;
use Text::CSV;

use Tarp::Style;

sub ITM     { 0 };
sub PKFILE { 1 };
sub PKEX   { 2 };
sub MASTER { 3 };

our $AUTOLOAD = 1;

# Autoloaded fields
my %fields = (
    verbose => 0,
    style   => undef,
    book    => undef,
    chapter => undef,
);

=head1 METHODS

=head2 new

    $gpk = Tarp::GenPK->new();

Initializes a new GenPK object. Options can be set through accessor methods.
Currently the following options are available:

=over

=item verbose

Sets the verbosity level

=back

This method imports C<Tarp::Style::ITM> with C<Tarp::Style::ITM::NLR> and
C<Tarp::GenPK::Style>

=cut

sub new {
    my $class = shift;
    
    confess "check usage" if @_;
    Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
    Tarp::Style->import( "Tarp::GenPK::Style" );
    
    my $self = {
        %fields,
        _fileIDCounter => {}, # e.g. 6et => 42
        _chapterData   => undef,
    };
    
    my $sty = Tarp::Style->new();
    $sty->impXforms( 1 );
    $self->{style} = $sty;
    
    bless $self, $class;
    return $self;
}

=head2 readCorrelation

    $gpk->readCorrelation();
    $gpk->readCorrelation( "correlation.csv" );

Reads a correlation CSV file. If no file is supplied, F<correaltion.csv> will
be used as default.  The process for extracting pickup list data from the
correlation is as follows.  First, column headers are examined in order to
identify the new, pickup and master ID columns.  Other columns that are not identified as one of these is ignored.

Columns that contain exercises are split into "path" and exercise portions.
The two are separated by a period.  The path portion is matched against the
C<csv_string> field in the C<TAS> file in order to extract a chapter and a section.

The file name for each pickup .tex file is estimated by transforming the contents
of the $book$ capture buffer in heading_PKEX to "filename" context and the
first two captured variables (names are ignored) from the csv_string entry to
"filename" context, and then interpolating the result using the "filename" entry
as a string.  This is available using the pickups() method.  Unique filenames
are given nicknames using the book name, followed by an underscore, followed by
an automatically incremented integer (e.g. foo, foo_2, foo_3 etc.)

=cut

sub readCorrelation {
    my $self = shift;
    my $correlation = shift || "correlation.csv";
    
    my $sty = $self->style();
    
    my %pickupFiles;
    
    open( CSV, $correlation )
        or croak "Could not open '$correlation' for reading: $!, stopped";
    
    my $header = <CSV>;
    chomp $header;

    my $csv = Text::CSV->new();
    $csv->parse( $header )
        or die "Parse error: " . $csv->error_diag() .
        ", stopped at $correlation line 1.\n";

    my @headings = $csv->fields();
    my $foundCols = $self->_identifyHeadings( \@headings );
    
    # Determine the new book
    # A single one for the whole file
    my $newBook = $headings[ $foundCols->{EX}->[0] ];
    my $newChapter = '';

    my %chapterData;
    my %fileIDCounter;

    # Now read the rest of the CSV file

    RECORD: while ( <CSV> ) {
        chomp;
        if ( ! $csv->parse( $_ ) ) {
            my $diag = $csv->error_diag();
            if ( length $diag ) {
                die( "Parse error: $diag, stopped at $correlation line $.\.\n" );
            } else {
                die "Parse error at $correlation line $.\.\n" ,
                "Check line endings.\n";
            }
        }
    
        my @fields = $csv->fields();
        
        my @dataRecord;
        
        # Fill @dataRecord...

        # - MASTER just moves to a different column
        $dataRecord[MASTER] = $fields[ $foundCols->{MASTER}->[0] ];
    
        # Exercise in new edition
        my $ex = $fields[ $foundCols->{EX}->[0] ];
        
        my ( $ch, $newSection, $exStr );
        if ( $sty->m( $sty->csvString() => $ex ) ) {
            my $varVals = $self->style()->mParens();
            ( undef, $ch, $newSection, $exStr) = @$varVals;
        } else {
            die "'$ex' (col. " . ( $foundCols->{EX}->[0] + 1 ) .
                ") does not match the '" . $sty->csvString() . "' entry, stopped at $correlation line $.\n";
        }

        croak "Could not get chapter and section from '$ex' using style's '$sty->csvString()' " ,
            "entry, stopped at $correlation line $.\n"
            unless length $ch && length $newSection;

        croak "Cannot handle multiple chapters, stopped at $correlation line $.\n"
            if ( $newChapter && $ch ne $newChapter );
        
        $newChapter = $ch;
        
        # Now newChapter, $newSection, $exStr contain new edition values

        $dataRecord[ITM] = $exStr;

        # Make "NEW" the last pickup column
        my   @pkCols = @{$foundCols->{PKEX}};
        push @pkCols, $foundCols->{NEW}->[0];
    
        my $firstPickupCol; # The leftmost filled pickup column
        my $firstPickup;    # The actual pickup (fully qualified) exercise or "new"
    
        # Look left to right across the pickup columns, and find the first
        # filled one.  ".." does not count as a filled column.
        for ( my $i = 0; $i < @pkCols; $i++ ) {
            $firstPickupCol = $pkCols[ $i ];
            $firstPickup = $fields[ $firstPickupCol ];
            last if ( $firstPickup && $firstPickup ne ".." );
        }

        my $pkFileID;
        my $pkFileName;
    
        my $pkEx = '';
        
        if ( $firstPickup eq "new" ) {
            $pkFileName = "(virtual)";
            $pkFileID = "new";
            $pkEx     = "..";
        } else {
            my $bookID;
            my $pkChapter;
            my $pkSection;

            if ( $sty->m( $sty->csvString() => $firstPickup ) ) {
                my $pkVars = $self->style()->mParens();
                # my @pkExSplit = ();
                ( undef, $pkChapter, $pkSection, $pkEx ) = @$pkVars;
                # $pkEx = join '', @pkExSplit;
            }
            
            die "Could not get chapter and section from '$firstPickup' using '" . $sty->csvString() .
                "' entry, stopped at $correlation line $.\n"
                    unless length $pkChapter && length $pkSection;
 
            $bookID = $headings[ $firstPickupCol ];
            $bookID =~ tr/ /_/; # Turn 6et Metric into 6et_Metric and so on            
        
            $pkFileName = $self->fileName(
                heading_PKEX => {
                    book => [ $bookID ]
                },
                $sty->csvString() => {
                    chapter => [ $pkChapter ],
                    section => [ $pkSection ]
                }
            ) . ".tex";
            
            if ( $pickupFiles{$pkFileName} ) {
                # Already had encountered this file in a previous section
                $pkFileID = $pickupFiles{ $pkFileName };
            } else {
                if ( my $c = $fileIDCounter{ $bookID }) {
                    # Set to next in the same book
                    $pkFileID = $bookID . "_" . $c;
                    $fileIDCounter{ $bookID }++;
                } else {
                    $pkFileID = $bookID;
                    $fileIDCounter{ $bookID } = 2;
                }
                $pickupFiles{$pkFileName} = $pkFileID;
            }
        }
        
        $dataRecord[PKFILE] = $pkFileID; # could be "new"
        $dataRecord[PKEX]   = $pkEx;     # could be ".."
        
        # Save under the right section
    
        if ( my $sectionData = $chapterData{$newSection} ) {
            push @{$sectionData->{records}}, \@dataRecord;
            $sectionData->{pkFileIDs}->{$pkFileID} = $pkFileName;
        } else {  # New section
            $chapterData{ $newSection } = {
                records => [ \@dataRecord ],
                pkFileIDs => { $pkFileID => $pkFileName },
            };
        }
    }
    
    @{$self}{ qw/_chapterData book chapter _fileIDCounter /}
        = ( \%chapterData, $newBook, $newChapter, \%fileIDCounter );
}

=head2 pickups

    $gpk->pickups();

Returns a copy of the pickups for this chapter, in a hashref structured as
follows:

    {
        section1 => {
            pkID1 => "pkFile1.tex",
            pkID2 => "pkFile2.tex",
            ... },
        section2 => { ... }
        ...
    }

=cut

sub pickups {
    my $self = shift;
    
    my %chaptData = %{$self->{_chapterData}};

    my %deepCopy = map {
        my %pkFileIDs = %{$chaptData{$_}->{pkFileIDs}};
        $_ => \%pkFileIDs
    } keys %chaptData;

    return \%deepCopy;
}

=head2 pickupBooks

    @ids = $gpk->pickupBooks();

Returns an array containing the pickup book IDs in the correlation file.  The
book ID is as identified in the heading: pickup file IDs "6et", "6et_2", "6et_3"
and so on all refer to pickup book "6et".

=cut

sub pickupBooks {
    my $self = shift;
    my $fileIDCounter = $self->{_fileIDCounter};
    
    return keys %$fileIDCounter;
}

=head2 createLists

    $gpk->createLists();

Creates pickup lists in the current directory.  Pickup data must first have been
loaded using readCorrelation().

=cut

sub createLists {
    my $self = shift;
    
    my ( $book, $chapter, $_chapterData )
        = @{$self}{qw/book chapter _chapterData/};
    
    my @secs = sort keys %$_chapterData;
    foreach my $section ( @secs ) {
        my $details = $_chapterData->{$section};

        my $OUTfile = $self->fileName(
            heading_EX => { book => [ $book ] },
            $self->style()->csvString() => {
                chapter => [ $chapter ],
                section => [ $section ]
            }
        ) . ".pklist";

        open( OUT, '>', $OUTfile ) or croak
            "Could not open '$OUTfile' for writing: $!, stopped";
        
        foreach my $record ( @{$details->{records}}) {
            print OUT "@$record\n";
        }
        
        close OUT;
        print "Wrote $OUTfile\n" if $self->verbose();
    }
}

=head2 book

    $gpk->book();

Returns the new edition book name.

=cut

=head2 chapter

    $ch = $gpk->chapter();

Returns the new edition chapter.

=cut

=head2 fileName

    $gpk->fileName( book => [ 'foo' ], chapter => [ 'bar' ] );

Returns the filename for these variables.  A filename is constructed by using the
"filename" entry and expanding the variables with the ones given to this function
as an argument.

This is used to determine the pickup list and output filenames.

=cut

sub fileName {
    my $self = shift;
    my %args = @_;

    my $sty = $self->style();
    
    my %newVars;
    while ( my ( $srcEntry, $vars ) = each %args ) {
        my $xfv  = $sty->xformVars( $vars, $srcEntry, $sty->filename() );
        @newVars{ keys %$xfv } = values %$xfv;
    }
    my ( $ostr ) = $sty->values( $sty->filename() );
    ( $ostr) = $sty->interpolateVars( $ostr, \%newVars );
    return $ostr;
}

sub _identifyHeadings {
    my $self = shift;
    my $headings = shift;
    
    my $sty = $self->style();
    
    my @briefHeadings = @$headings;  # "pruned" headings that we will fill out
    my %foundCols;
    
    # If a heading matches, put its source index in foundCols
    HEADING: for ( my $i = 0; $i < @$headings; $i++ ) {
        my $heading = $headings->[ $i ];
        my @colTypes = keys %{$sty->colTypes()};
        foreach my $col ( @colTypes ) {
            if ( $sty->m( "heading_$col" => $heading ) ) {
                my $p = $sty->mParens();
                $briefHeadings[ $i ] = $p->[1] if @$p > 1;
                if ( $foundCols{ $col } ) {
                    push @{$foundCols{ $col }}, $i;
                } else {
                    $foundCols{ $col } = [ $i ];
                }
                next HEADING;
            }
        }
    }

    # Required headings:
    # - One ex column
    # - One pickup column (non-new)
    
    if ( $self->verbose() ) {
        print "Identified the following columns (zero indexed):\n";
        while ( my ( $colType, $colIndeces ) = each %foundCols ) {
            my $indeces = @$colIndeces ? join ", ", @$colIndeces : "none!";
            print $self->style()->colTypes()->{$colType} . ": $indeces\n";
        }
    }
    
    croak "Could not identify all required CSV columns!\n"
        unless
            @{$foundCols{EX}}           == 1 &&
            @{$foundCols{PKEX}}         >  0 &&
            @{$foundCols{NEW}}          == 1 &&
            @{$foundCols{MASTER}}       == 1;

    @$headings = @briefHeadings;
    return \%foundCols;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/i ) {
        croak "Can't access '$name' field in class $type";
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

    perldoc Tarp::GenPK

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::GenPK
