#!/usr/bin/perl -w

use strict;
use Test::More tests => 35;
use Tarp::Style;

chdir "t/t01" or die "Could not chdir to t/t01: $!, stopped";

Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
Tarp::Style->import( "Tarp::LaTeXtract::Style" );

ok( my $sty = Tarp::Style->new(), "constructor returned non null" );

is_deeply( [ $sty->userValues( "itemTag_0_" ) ], [ '<illegal>-$ITM$' ], "default values itemTag[0]" );
is_deeply( [ $sty->userValues( "itemTag_1_" ) ], [ '$ITM$' ], "default values itemTag[1]" );
is_deeply( [ $sty->userValues( "itemTag_2_" ) ], [ '$ITM$' ], "default values itemTag[2]" );
is_deeply( [ $sty->userValues( "itemTag_3_" ) ], [ '$ITM$' ], "default values itemTag[3]" );

use Tarp::Counter::Numeric;
my $c = Tarp::Counter::Numeric->new();

is_deeply( [ ( $sty->interpolate( "itemTag_1_", Tarp::Style->INLINE ) )[ $sty->tasIndex( "itemTag_1_", 0 ) ] ],
          [ $c->matchTex() ], "iterp itemTag[1]" );

use Tarp::Counter::Latin;
$c = Tarp::Counter::Latin->new();

is_deeply( [ ( $sty->interpolate( "itemTag_2_", Tarp::Style->INLINE ) )[ $sty->tasIndex( "itemTag_2_", 0 ) ] ],
          [ $c->matchTex() ], "iterp itemTag[2]" );

use Tarp::Counter::Latin;
$c = Tarp::Counter::Roman->new();

is_deeply( [ ( $sty->interpolate( "itemTag_3_", Tarp::Style->INLINE ) )[ $sty->tasIndex( "itemTag_3_", 0 ) ] ],
          [ $c->matchTex() ], "iterp itemTag[3]" );

ok( $sty->save( "out.tas" ), "Saved out.tas" );

my $sty2 = Tarp::Style->new();

ok( $sty2->load( "out.tas" ), "Loaded out.tas" )
    or diag $sty2->errStr();

is_deeply( $sty->{_TAS}, $sty2->{_TAS}, "Data structures are the same" )
    and unlink "out.tas";

ok( ! $sty->load( "bad1.tas" ), "Error loading bad1" );

like ( $sty->errStr(), qr/itemTag\[1\].*empty list not allowed/i, "Empty list for exTag" );

ok( ! $sty->load( "extag.tas" ), "Error loading extag.tas" );

like( $sty->errStr(), qr/itemTag\[1\].*should contain.*\$ITM\$/, "extag.tas error" );

ok( ! $sty->load( "extag2.tas" ), "Error loading extag2.tas" );

like( $sty->errStr(), qr/itemTag\[1\].*empty list not allowed/i, "extag2.tas error" );

ok( ! $sty->load( "parttag.tas" ), "Error loading parttag.tas" );

like( $sty->errStr(), qr/itemTag\[2\].*empty list not allowed/i, "parttag.tas error" );

ok( ! $sty->load( "nobegin.tas" ), "Error loading nobegin.tas" );

like( $sty->errStr(), qr/beginTag.*not found/i, "nobegin.tas error" );

ok( ! $sty->load( "noend.tas" ), "Error loading noend.tas" );

like( $sty->errStr(), qr/endTag.*not found/i, "noend.tas error" );

ok( ! $sty->load( "emptybegin.tas" ), "Error loading emptybegin.tas" );

like( $sty->errStr(), qr/beginTag.*empty list not allowed/i, "emptybegin.tas error" );

ok( ! $sty->load( "rxerrors.tas" ), "Error loading rxerrors.tas" );

like( $sty->errStr(), qr/beginTag.*Regexp error/i, "rxerrors.tas beginTag error" );
like( $sty->errStr(), qr/endTag.*Regexp error/i,   "rxerrors.tas endTag error" );
like( $sty->errStr(), qr/itemTag\[1\].*Regexp error/i, "rxerrors.tas exTag error" );
like( $sty->errStr(), qr/itemTag\[2\].*Regexp error/i, "rxerrors.tas partTag error" );
like( $sty->errStr(), qr/itemTag\[3\].*Regexp error/i, "rxerrors.tas subPartTag error" );
like( $sty->errStr(), qr/sequenceRestart.*Regexp error/i, "rxerrors.tas sequenceRestart error" );
like( $sty->errStr(), qr/Perl didn't like.*beginTag/i, "beginTag RX err explanation" );

ok( ! $sty->load( "multibegin.tas" ), "Error loading multibegin.tas" );

like( $sty->errStr(), qr/endTag\[1\].*empty list/i, "multibegin.tas endTag[1] error" );


