#!/usr/bin/perl -w
use strict;

use Tarp::Test::Files;
use Tarp::GenSkel;
use Test::More tests => 2;

chdir "t/t11" or die "could not chdir to t/t11: $!";

sub runTest {
    my $x = shift;
    my $io = IO::File->new();
    $io->open( ">out/skel.txt" ) or die "Could not open out/skel.txt for writing: $!, stopped";
    $x->printSkel( $io );
}

my $x = Tarp::GenSkel->new(); # class I am testing

$x->style()->load( "in.tas" )
    or die "Could not load in.tas";

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $x ] );

$t->case( "empty" );

$x->addChunk( "01a", "01a" );
$x->addChunk( "01ai", "01ai" );
$x->addChunk( "01aii", "01aii" );
$x->addChunk( "01b", "01b" );

$t->case( "simple" ); # c01
