#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

use Tarp::LaTeXtract;
use Tarp::Test::Files;

use Carp;
plan tests => 27;

my $case = 1;

sub runTest {
        my $ltx = shift;
        
        ok( $ltx->style()->load( "in.tas" ), "loaded in.tas" )
                or diag $ltx->style()->errStr();

        ok( $ltx->read( "in/in.tex" ), "read in/in.tex" )
                or diag $ltx->errStr();

        open( OUT, '>', "out/dataout.txt" )
            or die "Could not open out/dataout.txt for writing: $!";

        select OUT;
        $ltx->dumpLines();
        
        select STDOUT;
        close OUT;
}

my $t = Tarp::Test::Files->new();

my $ltx = Tarp::LaTeXtract->new();
$ltx->maxLevel( 2 );

$t->generator( [\&runTest, $ltx] );

package main;

chdir ( 't/t10' ) or die "Could not chdir to t/t10: $!";

# Tarp::LaTeXtract->debug( 1 );
$t->case( "Goes down to level -1 between 2b and 3a" ); # c01
$t->case( "Two sequences" ); # c02
$t->case( "01b and 01a out of order." ); # c03
$t->case( "Dummy tags" ); # c04
$t->case( "100+ exercises" ); # c05
$t->case( "Other matching tag in exercises" ); # c06
$t->case( "Matching filename tag" ); # c07
$t->case( "two levels of begin and end tags" ); # c08
$t->case( "two levels of begin and end tags" ); # c08
