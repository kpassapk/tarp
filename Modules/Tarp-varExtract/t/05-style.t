#!perl

use strict;
use Test::More tests => 8;
use Tarp::Style;

my $sty = Tarp::Style->new();

my $pe = $sty->entries( 0 );

Tarp::Style->import( "Tarp::varExtract::Style" );

is( Tarp::varExtract::Style->fnameEntry(), "filename", "class fnameEntry is filename" );

$sty = Tarp::Style->new();

isa_ok( $sty, "Tarp::Style" );

use Data::Dumper;

is( $sty->entries( 0 ), $pe + 1, "1 entry more than parent style" )
    or diag Dumper [ $sty->entries( 0 ) ];

ok( $sty->exists( "filename" ), "'filename' exists" );

Tarp::varExtract::Style->fnameEntry( "mog" );

$sty = Tarp::Style->new();

is( $sty->entries( 0 ), $pe + 1, "same number of entries" )
    or diag Dumper [ $sty->entries( 0 ) ];

ok( $sty->exists( "mog" ), "'mog' exists" );

$sty->save( "out.tas" );

my $sty2 = Tarp::Style->new();
ok( $sty2->load( "out.tas" ), "loaded out.tas" ) and unlink "out.tas";

is_deeply( $sty2->{_TAS}, $sty->{_TAS}, "structures are the same" );

