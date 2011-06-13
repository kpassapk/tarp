#!perl

BEGIN {
    use Cwd;
    our $directory = cwd;
    use File::Spec;
    our $libDir = File::Spec->catfile( $directory, "..", "Resources", "lib" );    
}

use lib $libDir;
use strict;
use File::Copy;
use Test::More tests => 4;
use File::Copy::Recursive qw/dircopy pathrmdir/;


mkdir "t/tut";

my $tut_dir = "../../Tutorials/Creating an Example Manuscript";

dircopy $tut_dir, "t/tut" or die "Could not copy $tut_dir to t/tut: $!, stopped";
copy "ansman.pl", "t/tut" or die "could not copy ansman.pl to t/tut: $!, stopped";
copy "ansman.tas", "t/tut" or die "could not copy ansman.tas to t/tut: $!, stopped";

chdir "t/tut" or die "Could not chdir to t/tut: $!, stopped";

# Tutorial test is with entire directory
# which contains 7et0201.tex

ok( ! -e "7et0201-answers.tex", "section 01 file does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/7et0201\.tex -> 7et0201-answers\.tex/, "tut stdout" );
}

ok( -e "7et0201-answers.tex", "7et0201-answers exists" );

chdir "..";

copy "tut/7et0201-answers.tex", "out"
    or die "Could not copy 7et0201-answers.tex to 'out': $!, stopped";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "7et0201-answers.tex" );

pathrmdir( "tut" ) or die "Could not remove \"tut\": $!, stopped";
