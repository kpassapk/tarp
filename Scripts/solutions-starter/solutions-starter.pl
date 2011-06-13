#!/usr/bin/perl -w

=pod

Instructions:

To do a chapter of solutions you need the following:

- A correlation.csv file.
- The pickup files from a previous edition as referred to in the .csv file
- The manuscript files for this chapter of the new edition
- solutions-starter.tas

1.  Before you do the first chapter, create an empty directory with the name of
    the new book.  Copy this script into that directory. Make a subdirectory
    for the first chapter and put the correlation.csv in there.

2.  Run solutions-starter.pl.  This will create BOOK-CONFIG.yml.

3.  Edit BOOK-CONFIG.yml to replace the placeholders with the locations the
    manuscript and one or more directories below which the pickup .tex files
    may be found. These are the root directories for the entire book, not
    for a single chapter within that book. The path can be a directory ( e.g.
    C:\mybooks\3c3 ) or a UNC share name ( \\server\share\3c3 ).
    Do NOT use a trailing backslash. Spaces in directory names are OK.

4.  Run solutions-starter.pl again.  A collection of pickup lists will be
    created in the chapter directory, and CHAPT-CONFIG.yml will be
    created containing the names of the pickup files.  The titles for each section
    will also be put in the CHAPT-CONFIG.yml by reading the manuscript files.
    
5.  Verify the file names and sections in CHAPT-CONFIG.yml.

6.  If they are correct, re-run solutions-starter.pl. The pickup files will be
    gathered from the directories specified in BOOK-CONFIG.yml by performing a
    search. If found, each pickup file will be copied into the same directory
    the script is in. A message will appear telling you whether the pickup files
    could be found or not.  The titles for this chapter will also be extracted
    from the manuscript files and put into CHAPT-CONFIG.yml.  If there is any
    discrepancy between the sections found in the manuscript files and those
    in the csv correlation file, an error message will be printed.

7.  Run LaTeXtract on all of the pickup files. If an error message is printed,
    add or remove tags (or entries in your .tas file) until those messages go away.

6.  If all of the pickup files are found and latextractable, then open each of
    the .pklist files in Komodo, running LaTeXcombine and GenTex to get the
    final .tex file.

=cut

BEGIN {
    use Cwd;
    our $directory = cwd;
}

use lib $directory;
use strict;

use Tarp::GenPK;
use Tarp::varExtract;

open( MOD, '>_FileNameAdjust.pm' );
print MOD <<END_OF_MODULE;
package _FileNameAdjust;

sub new {
    my \$class = shift;
    my \$self = bless \$class->SUPER::new(), \$class;
    return \$self;
}

sub _heading_EX2filename {
    my \$self = shift;
    return \$self->_subName( \@_ );
}

sub _heading_PKEX2filename {
    my \$self = shift;
    return \$self->_subName( \@_ );
}

# remove trailing letter
sub _subName {
    my \$self = shift;
    my ( \$v ) = \@{\$_[1]};
    \$v =~ tr/[A-Z]/[a-z]/;
    \$v =~ s/\\d\$//;
    return [ \$v ];
}

1; # End of _FileNameAdjust
END_OF_MODULE
close MOD;

Tarp::Style->debug( 0 );
$Carp::Verbose = 1;
Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
Tarp::Style->import( "Tarp::varExtract::Style" );
Tarp::Style->import( "Tarp::GenPK::Style", "_FileNameAdjust" );
Tarp::varExtract::Style->fnameEntry( "ms_filename" );

unlink "_FileNameAdjust.pm"
    or warn "Could not remove '_FileNameAdjust.pm: $!";

if ( ! -e "BOOK-CONFIG.yml" ) {
    # Create a new YAML file:
    # Go to each chapter and read the correlation.csv with GenPK
    # Get the amount of pickups in the whole correlation, i.e. all sections 

    my $yaml = YAML::Tiny->new();
    $yaml->[0]->{'Current chapter'} = 1;
    $yaml->[0]->{'Manuscript path'} = 'C:\path\to\manuscript or \\server\path\to\manuscript';
    $yaml->[0]->{'Pickup paths'} = [ 'C:\path\to\pickup_files or \\server\path\to\pickup_files' ];
    
    $yaml->write( "BOOK-CONFIG.yml" ) or die "Could not write BOOK-CONFIG.yml: "
        . YAML::Tiny->errstr() . "\n";
    print "\nWrote BOOK-CONFIG.yml\n" and exit 0;
}

# Read YAML file

my $yaml = YAML::Tiny->read( "BOOK-CONFIG.yml" );

die "Error while reading BOOK-CONFIG.yml: "
    . YAML::Tiny->errstr() . "\n" if ! $yaml;

my $BK_Current_chapter = $yaml->[0]->{'Current chapter'};
my $BK_Manuscript_path = $yaml->[0]->{'Manuscript path'};
my @BK_Pickup_paths = @{$yaml->[0]->{'Pickup paths'}};

use Cwd;

{
    my @ps = ( $BK_Manuscript_path, @BK_Pickup_paths );
    foreach ( @ps ) {
        $_ = File::Spec->catfile( cwd, $_ )
            unless File::Spec->file_name_is_absolute( $_ );
    }
    ( $BK_Manuscript_path, @BK_Pickup_paths ) = @ps;
}

chdir $BK_Current_chapter or die "Could not chdir to $BK_Current_chapter: $!, stopped";

if ( ! -e "CHAPT-CONFIG.yml" ) {
    my $gpk = Tarp::GenPK->new();
    $gpk->style()->load( "../solutions-starter.tas" )
        or die $gpk->style()->errStr();
    $gpk->verbose( 1 );
    print "Reading 'correlation.csv'...\n";
    
    $gpk->readCorrelation();
    # Generate pickup lists, overwriting old ones.
    print "\nCreating pickup lists...\n";
    $gpk->createLists();
    
    # Create CHAPT-CONFIG.yml
    $yaml = YAML::Tiny->new();
    
    $yaml->[0]->{'Pickup files'} = $gpk->pickups();
    my $sectZero = $gpk->fileName(
            heading_EX => { book    => [ $gpk->book() ] },
            $gpk->style()->csvString() => {
                chapter => [ $gpk->chapter() ],
                section => [ qw/00/ ] } ) . ".tex";
    $yaml->[0]->{'Manuscript master file'} = $sectZero;

    $yaml->write( "CHAPT-CONFIG.yml" ) or die "Could not write CHAPT-CONFIG.yml: " ,
        YAML::Tiny->errstr(), ", stopped";
    print "\nWrote CHAPT-CONFIG.yml\n";
    exit 0;
}

# Read pickups in CHAPT-CONFIG.yml

$yaml = YAML::Tiny->read( "CHAPT-CONFIG.yml" );
die "Could not load CHAPT-CONFIG.yml: " , YAML::Tiny->errstr(), ", stopped"
    unless $yaml;
print "Read 'CHAPT-CONFIG.yml'\n";

my $ch_msMaster = $yaml->[0]->{'Manuscript master file'};
my %ch_Pickups = %{$yaml->[0]->{'Pickup files'}};


#====== COPY PICKUP FILES ======================================================

use Cwd;

use File::Find;
use File::Spec;
use File::Copy;

my $pickupsDest = cwd();

my $NpksCopied = 0;
sub xferPks {
    my $file = $_;
    $file =~ tr/[A-Z]/[a-z]/; # ignore case
    
    while ( my ( $sect, $pickupInfo ) = each %ch_Pickups ) {
        my %pkInfo = %$pickupInfo;
        while ( my ( $fid, $fname ) = each %pkInfo ) {
            my ( undef, undef, $sp ) = File::Spec->splitpath( $fname );
            $sp =~ tr/[A-Z]/[a-z]/;
            $pkInfo{ $fid } = $sp;
        }
        my %pkfByName = reverse %pkInfo;
        
        if ( my $fid = $pkfByName{ $file } ) {
            my $fqf = $ch_Pickups{$sect}{$fid};
            copy $File::Find::name,
                 File::Spec->catfile( $pickupsDest, $fqf )
                or die "Could not copy " , $File::Find::name ,
                " to $fqf: $!, stopped";
            ++$NpksCopied;
            print "Copied '" , $File::Find::name, "' to '$fqf'\n";
        }
    }
};

for ( @BK_Pickup_paths ) {
    die "'BOOK_CONFIG.yml' pickup path " . $_ . " not found"
        if ( ! -e $_ );
    die "'BOOK_CONFIG.yml' pickup path '$_' is not a directory"
        if ( -f _ );
}

print "\nCopying pickup files...\n";
find( \&xferPks, @BK_Pickup_paths );
print "$NpksCopied file(s) copied\n";

#====== GET SECTION TITLES =====================================================

print "\nGetting titles...\n";
my $msDir;

die "BOOK_CONFIG.yml manuscript path '$BK_Manuscript_path' not found"
    unless -e $BK_Manuscript_path;
die "BOOK_CONFIG.yml manuscript path '$BK_Manuscript_path' is not a directory"
    if -f _;

find ( \&findmsDir, $BK_Manuscript_path );

sub findmsDir {
    if ( $_ eq $ch_msMaster ) {
        $msDir = $File::Find::dir;
    }
}

die "CHAPT-CONFIG.yml manuscript master file '$ch_msMaster' not found in '$BK_Manuscript_path' "
    , "or its subdirectories, stopped" unless defined $msDir;

print "Found manuscript master file '$ch_msMaster' in '$msDir'\n";
my $oldDir = cwd();

chdir $msDir or die "Could not chdir to $msDir: $!, stopped";

# Use varExtract to get variables & put them in CHAPT-CONFIG.

my $TASfile = File::Spec->catfile( $oldDir, "..", "solutions-starter.tas" );
my $vex = Tarp::varExtract->new();
$vex->verbose( 1 );
$vex->nicknameVar( -1 );

$vex->style()->load( $TASfile )
    or die $vex->style()->errStr();

$vex->extract();

my $titles = $vex->vars();

# Promote section zero to apply to all sections

my $msNickname = $vex->nickname( $ch_msMaster )
    or die "Could not get nickname for '$ch_msMaster' ";

my $msTitles = $titles->{$msNickname};
delete $titles->{$msNickname};

while ( my ( $section, $title ) = each %$titles ) {
    @{$title}{keys %$msTitles} = values %$msTitles;
}

# Save as YAML data
$yaml->[0]->{titles} = $titles;

chdir $oldDir or die "Could not chdir to $oldDir: $!, stopped";

print "Updating CHAPT-CONFIG.yml\n";

$yaml->write( "CHAPT-CONFIG.yml" )
    or die "Could not write to CHAPT-CONFIG.yml: " . YAML::Tiny->errstr() . ",stopped";

#====== REPORT MISSING PICKUPS =================================================

my $Nfound = 0;
my $Ntotal = 0;

print "\nPickups Per Section:\n";

while ( my ( $section, $pickupInfo ) = each %ch_Pickups ) {
    my $NfoundSect = 0;
    my $NtotalSect = 0;
    my @missing = ();
    foreach my $id ( keys %$pickupInfo ) {
        my $file = $pickupInfo->{$id};
        next if $id eq "new";
        if ( -e $file ) {
            $Nfound++; $NfoundSect++;
        } else {
            push @missing, $file;
        }
        $Ntotal++; $NtotalSect++;
    }
    print "\t$section: " . ( $NfoundSect == $NtotalSect ?
        "OK\n" : "NOT OK: missing " . join( ", ", @missing ) . "\n" );
}

if ( $Ntotal > 0 ) {
    print "Have $Nfound / $Ntotal (" . int( $Nfound / $Ntotal * 100 ) . "\%) ",
        "of the pickup files needed for this chapter.\n";
} else {
    print "No pickup files needed for this chapter (?)\n";
}

exit 1 unless $Nfound == $Ntotal;
