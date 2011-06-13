#!perl

use strict;
use File::Copy;
use Test::More tests => 3;

copy "exitemize.pl",  "t" or die "could not copy exitemize.pl to t: $!, stopped";

chdir "t" or die "Could not chdir to t: $!, stopped";

ok( ! -e "bla_itm.tex", "bla_itm.tex does not exist" );

system( "perl exitemize.pl 2>&1 1>tmpfile" ) == 0
    or die "system exitemize.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/bla.tex: 1 insertions -> bla_itm.tex/, "tut stdout" );
}

move "bla_itm.tex", "out"
    or die "Could not copy bla_itm.tex to 'out': $!, stopped";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "bla_itm.tex" );

