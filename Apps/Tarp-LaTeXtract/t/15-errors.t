#!/usr/bin/perl -w

use strict;
use warnings;
use Cwd;

use Test::More tests => 42;

use Tarp::Test::Files;
use Tarp::LaTeXtract;

chdir ( 't/t15' ) or die "Could not chdir to t/t15: $!";

sub runTest {
    my $x = shift;
    my $c = cwd;
    $c =~ s/.*\///;
    
    ok( $x->style()->load(), "loaded $c style" )
        or diag $x->style()->errStr();
    $x->style()->file( undef );
    ok( ! $x->read( "in/in.tex" ), "read() returns false" );
    open OUT, ">out/errout.txt" or die "Could not open errout.txt: $!, stopped";
    print OUT $x->errStr() . "\n";
    close OUT;
}

my $x = Tarp::LaTeXtract->new();

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $x ] );

$t->case(  "Missing tag" ); # c01

$x->enforceOrder( 1 );

$t->case(  "Out of order tag" ); # c02

$x->enforceOrder( 0 );

$t->case( "sequenceRestart found at level 1" ); # c03
$t->case( "Unexpected tag"                   ); # c04
$t->case( "beginTag at maximum level"        ); # c05
$t->case( "Two consecutive beginTags"        ); # c06
$t->case( "endTag as first matching tag"     ); # c07
$t->case( "endTag at file level"             ); # c08
$t->case( "endTag after beginTag with no item tags in between" ); # c09

$x->context( 5 );
$t->case( "five lines context" ); # c10

$x->context( 10 );
$t->case(  "more lines of context than are available" ); # c11

$x->context( 4 );
$t->case(  "empty begin/end at level zero"); # c12

$t->case(  "EOF at nonzero level" ); # c13

$t->case(  "c13 but with dummy tags" ); # c14
