#!perl

use strict;
use File::Copy;
use Test::More tests => 9;

BEGIN {
    use Cwd;
    our $directory = cwd;
    use File::Spec;
    our $libDir = File::Spec->catfile( $directory, "..", "Resources", "lib" );    
}

use File::Copy::Recursive qw/dircopy pathrmdir/;

mkdir "t/tut";

diag "Testing expandex.pl with tutorial files";

# dircopy $tut_dir,    "t/tut" or die "Could not copy $tut_dir to t: $!, stopped";
copy "expandex.pl",  "t/tut" or die "could not copy expandex.pl to t/tut: $!, stopped";
copy "expandex.tas", "t/tut" or die "could not copy expandex.tas to t/tut: $!, stopped";

# diag "Copied tutorial files OK";

chdir "t/tut" or die "Could not chdir to t/tut: $!, stopped";

# Tutorial test is with entire directory
# which contains two files, for sections 01 and 02

ok( ! -e "6et0101-new.tex", "section 01 file does not exist" );
ok( ! -e "6et0102-new.tex", "section 02 file does not exist" );

system( "perl expandex.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/6et0101_itm.tex: 16e 5vid/, "tut stdout" );
    like( $out, qr/6et0102_itm.tex: 10e 5vid/, "tut stdout" );
}

ok( -e "6et0101-new.tex", "section 01 file exists" );
ok( -e "6et0102-new.tex", "section 02 file exists" );


chdir "..";


move "tut/6et0101-new.tex", "out/6et0101.tex"
    or die "Could not move 6et0101-new.tex to 'out': $!, stopped";
    
move "tut/6et0102-new.tex", "out/6et0102.tex"
    or die "Could not move 6et0101-new.tex to 'out': $!, stopped";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "6et0101.tex" );
Tarp::Test::Files->asExpected( "6et0102.tex" );

move "tut/expandex.pl",  "." or die "could not copy expandex.pl to t: $!, stopped";
move "tut/expandex.tas", "." or die "could not copy expandex.tas to t: $!, stopped";

system( "perl expandex.pl --file=6et0407_itm.tex --leave-tmp 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/6et0407_itm.tex: 0e 0vid/, "6et0407 stdout" );
}

unlink "6et0407_new.tex";

