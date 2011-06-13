#!/usr/bin/perl -w

# This script uses Tarp::Burn to rename files in the current directory.

# Author's book names to Tarp's book names.
my %BOOK_NAMES = (
    c4e => "4c",
    c3e => "3c",
);

# Project strings and the equivalent file name.
# The case is ignored (that's the /i thing below)
my %PROJS = (
    qr/Applied Project/i => 'AP',
    qr/Discovery Project/i => 'DP'
);

# The above appear in the first N lines of the file...
my $HEADING_LINES = 20;

use strict;
use Tarp::Burn;

# Left pad a number with zeroes, if result is numeric, otherwise
# just return the original value.
sub leftPad {
    my $val = shift;
    if ( $val =~ /\d/ ) {
        return sprintf( "%02d", $val );
    } else { return $val; }
}

my $projectCounter = 1;

my $burn = Tarp::Burn->new();

$burn->style()->load( "stewart2techarts.tas" )
    or die $burn->style()->errStr();

# The result of these functions / replacements matches
# the destination spec in the TAS file.
$burn->bulkRename(
    BOOK    => \%BOOK_NAMES,
    
    CHAPTER => \&leftPad, # see leftPad above

    SECTION => \&leftPad, # see leftPad above
    
    PROJECT => sub {
        my $val = shift;
        my $opts = shift;
        
        # Read the first few lines of the file and find the PROJECT names.
        # Return the project name plus a two digit counter 01, 02...
        
        my $currentFile = $_;
        open FILE, $currentFile or die "Could not open $currentFile: $!, stopped";
LINE:   while ( <FILE> ) {
            while ( my ( $pattern, $str ) = each %PROJS ) {
                if ( $_ =~ $pattern ) {
                    $val = $str . sprintf ( "%02d", $projectCounter++ );
                }
            }
            last LINE if $. > $HEADING_LINES; # Skip the rest of the file
        }
        return $val;
    }
)