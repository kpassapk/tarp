#!/usr/bin/perl -w

use strict;

use Tarp::Style;
use Test::More tests => 22;

Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );

my $sty = Tarp::Style->new();

my $pe = scalar $sty->entries( 0 );

Tarp::Style->import( "Tarp::GenPK::Style" );

chdir "t/t05" or die "Could not chdir to t/t05: $!, stopped";

$sty = Tarp::Style->new();

isa_ok( $sty, "Tarp::Style" );

use Data::Dumper;

is( $sty->entries( 0 ), $pe + 6, "six entries more than parent style" )
    or diag Dumper [ $sty->entries( 0 ) ];

is( $sty->csvString(), "csv_string", "csvString method" );
is( $sty->filename(), "filename", "filename method" );

$sty->save( "out.tas" );

my $sty2 = Tarp::Style->new();
ok( $sty2->load( "out.tas" ), "loaded out.tas" ) and unlink "out.tas";

is_deeply( $sty2->{_TAS}, $sty->{_TAS}, "structures are the same" );

my $tas = <<TASFILE;

itemTag[0] = <illegal>-\$ITM\$
itemTag[1] = \$ITM\$
itemTag[2] = \$ITM\$
itemTag[3] = \$ITM\$

TASFILE

ok( ! $sty->loadString( $tas ), "load empty tasfile" );

like( $sty->errStr(), qr/csv_string.*not found/i, "csv_string not found" );

my $tas2 = $tas . <<TASFILE;

filename =
csv_string =

TASFILE

ok( ! $sty->loadString( $tas2 ), "load empty entries" );

like( $sty->errStr(), qr/csv_string.*empty list not allowed/i, "csv_string empty" );
like( $sty->errStr(), qr/filename.*empty list not allowed/i, "filename empty" );

my $tas3 = $tas . <<TASFILE;

filename = a b
csv_string = c d

TASFILE

ok( ! $sty->loadString( $tas3 ), "load empty entries" );

like( $sty->errStr(), qr/csv_string.*must have 3 variables/i, "csv_string var1" );
like( $sty->errStr(), qr/csv_string.*should contain.*itemString/i, "csv_string contains itemString" );

like( $sty->errStr(), qr/filename.*should contain.*book/i, "filename var1" );
like( $sty->errStr(), qr/filename.*should contain.*chapter/i, "filename var2" );
like( $sty->errStr(), qr/filename.*should contain.*section/i, "filename var3" );
like( $sty->errStr(), qr/filename.*Multiple values not allowed/i, "filename var3" );

ok( $sty->m( "csv_string", "01.01.01" ), "match 01" );
ok( $sty->m( "csv_string", "01.01.01a" ), "match 01a" );
ok( $sty->m( "csv_string", "01.01.01aiv" ), "match 01aiv" );
ok( ! $sty->m( "csv_string", "01.01.abcd" ), "cant match abcd" );
