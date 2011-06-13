#!perl

BEGIN {
    use Cwd;
    our $d = cwd;
}

chdir "t/t06" or die "Could not chidr to t/t06: $!, stopped";

use lib $d;
use strict;

use Test::More tests => 10;
use Tarp::LaTeXtract;

my $l = Tarp::LaTeXtract->new();

$l->context( 10 );
$l->style()->values( "sequenceRestart", "seq" );

ok( ! $l->read( "seq0.txt" ), "error" );
like( $l->errStr, qr/endTag at file level/, "error looks right" );

# $l->dumpLines();

$l->extractSeq( 0 );

ok( $l->read( "seq0.txt" ), "read okay this time" );

eval "use Test::Differences";

my $lines = '';
open LN, '>', \$lines;
select LN;
$l->dumpLines();
close LN;

SKIP: {
    skip 2, "Test::Differences required for these tests" if $@;
    eq_or_diff( $lines, <<END_OF_LINES
seq0: 1 9
seq1: 10 11
01: 2 8
01a: 4 4
01b: 7 7
END_OF_LINES
, "lines ok" );

}

$l->extractSeq( -1 );

ok( ! $l->read( "seq0.txt" ), "error again with extractSeq -1" );
like( $l->errStr, qr/endTag at file level/, "returns error" );

ok( ! $l->read( "seq1.txt" ), "error" );
like( $l->errStr, qr/endTag at file level/, "seq1 returns error" );

$l->extractSeq( 1 );

ok( $l->read( "seq1.txt" ), "read okay this time" );

eval "use Test::Differences";

$lines = '';
open LN, '>', \$lines;
select LN;
$l->dumpLines();
close LN;

SKIP: {
    skip 2, "Test::Differences required for these tests" if $@;
    eq_or_diff( $lines, <<END_OF_LINES
seq0: 1 1
seq1: 2 11
01: 4 10
01a: 6 6
01b: 9 9
END_OF_LINES
, "lines ok" );

}

